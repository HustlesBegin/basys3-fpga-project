library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity auth_block is
    Port (
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;
        btn_cfg_p      : in  STD_LOGIC;                        -- BTNL: salir/entrar CONFIG
        btn_ok_p       : in  STD_LOGIC;                        -- BTNC: confirmar (guardar / intentar)
        sw_key         : in  STD_LOGIC_VECTOR(3 downto 0);     -- SW0..SW3
        tick_1hz       : in  STD_LOGIC;                        -- de clk_divider

        access_granted : out STD_LOGIC;                        -- 1 => acceso concedido
        lock_active    : out STD_LOGIC;                        -- 1 => en bloqueo
        attempts_left  : out unsigned(1 downto 0);             -- 0..3
        remaining_sec  : out unsigned(5 downto 0);             -- 30..0
        state_debug    : out STD_LOGIC_VECTOR(2 downto 0)      -- debug de estado
    );
end auth_block;

architecture Behavioral of auth_block is

    ----------------------------------------------------------------
    -- Estados
    ----------------------------------------------------------------
    type state_type is (S_CONFIG, S_VERIFY, S_CHECK, S_LOCK, S_DONE);
    signal state_reg, state_next : state_type;
    signal state_prev            : state_type;

    ----------------------------------------------------------------
    -- Señales internas
    ----------------------------------------------------------------
    signal stored_key    : STD_LOGIC_VECTOR(3 downto 0);
    signal match         : STD_LOGIC;
    signal attempts      : unsigned(1 downto 0);
    signal locked_int    : STD_LOGIC;

    -- Pulsos
    signal new_try_pulse        : STD_LOGIC := '0';  -- al entrar a S_CHECK
    signal reload_attempts      : STD_LOGIC := '0';  -- 1 ciclo: recargar contador
    signal reload_pending       : STD_LOGIC := '0';  -- flag 1 ciclo en S_VERIFY

    -- Temporizador 30 s
    signal timer_start   : STD_LOGIC := '0';
    signal timer_active  : STD_LOGIC;
    signal timer_done    : STD_LOGIC;
    signal rem_secs      : unsigned(5 downto 0);

    -- Carga de clave
    signal load_en_key   : STD_LOGIC := '0';

begin
    ----------------------------------------------------------------
    -- Habilitar carga de clave SOLO en S_CONFIG con BTNC
    ----------------------------------------------------------------
    process(state_reg, btn_ok_p)
    begin
        if state_reg = S_CONFIG then
            load_en_key <= btn_ok_p;
        else
            load_en_key <= '0';
        end if;
    end process;

    key_reg_inst : entity work.key_storage
        port map (
            clk     => clk,
            rst     => rst,
            load_en => load_en_key,
            key_in  => sw_key,
            key_out => stored_key
        );

    key_chk_inst : entity work.key_checker
        port map (
            key_try  => sw_key,
            key_real => stored_key,
            match    => match
        );

    ----------------------------------------------------------------
    -- Contador de intentos (con reload explícito)
    ----------------------------------------------------------------
    attempts_inst : entity work.attempt_counter_auth
        port map (
            clk           => clk,
            rst           => rst,
            new_try       => new_try_pulse,
            success       => match,
            reload        => reload_attempts,       -- << aquí va el reload
            attempts_left => attempts,
            locked        => locked_int
        );

    ----------------------------------------------------------------
    -- Temporizador 30 s
    ----------------------------------------------------------------
    timer30_inst : entity work.sec_timer
        generic map ( SECONDS => 30 )
        port map (
            clk_1hz   => tick_1hz,
            rst       => rst,
            start     => timer_start,
            active    => timer_active,
            done      => timer_done,
            remaining => rem_secs
        );

    -- Start nivelado
    timer_start <= '1' when (state_reg = S_LOCK and timer_active = '0' and timer_done = '0') else '0';

    ----------------------------------------------------------------
    -- Registro de estado + estado previo
    ----------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state_reg  <= S_CONFIG;
            state_prev <= S_CONFIG;
        elsif rising_edge(clk) then
            state_prev <= state_reg;
            state_reg  <= state_next;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Pulso: al ENTRAR a S_CHECK (consumir intento)
    ----------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            new_try_pulse <= '0';
        elsif rising_edge(clk) then
            if (state_prev /= S_CHECK) and (state_reg = S_CHECK) then
                new_try_pulse <= '1';
            else
                new_try_pulse <= '0';
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Pulso de RELOAD al ENTRAR a S_VERIFY desde LOCK o CONFIG
    -- y flag 'reload_pending' para ignorar attempts=0 en el primer ciclo de VERIFY
    ----------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            reload_attempts <= '0';
            reload_pending  <= '0';
        elsif rising_edge(clk) then
            -- Pulso de reload
            if (state_prev = S_LOCK   and state_reg = S_VERIFY) or
               (state_prev = S_CONFIG and state_reg = S_VERIFY) then
                reload_attempts <= '1';
                reload_pending  <= '1';  -- habilita "gracia" de 1 ciclo
            else
                reload_attempts <= '0';
                -- limpiar la "gracia" tras 1 ciclo en VERIFY
                if state_reg = S_VERIFY then
                    reload_pending <= '0';
                else
                    reload_pending <= reload_pending;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- FSM combinacional
    ----------------------------------------------------------------
    process(state_reg, btn_ok_p, btn_cfg_p, match, attempts, timer_done, reload_pending)
    begin
        state_next <= state_reg;

        case state_reg is
            ----------------------------------------------------------------
            -- MODO CONFIGURACIÓN:
            -- Ahora la rúbrica se cumple:
            --  - Colocas la clave con SW
            --  - Presionas BTNC (btn_ok_p)
            --  - Se guarda la clave (load_en_key) y pasas DIRECTO a S_VERIFY
            -- BTNL aquí ya no se usa para salir de CONFIG.
            ----------------------------------------------------------------
            when S_CONFIG =>
                if btn_ok_p = '1' then
                    state_next <= S_VERIFY;
                else
                    state_next <= S_CONFIG;
                end if;

            ----------------------------------------------------------------
            -- MODO VERIFICACIÓN:
            --  - BTNL (btn_cfg_p): volver a S_CONFIG para reprogramar clave
            --  - BTNC (btn_ok_p): intentar clave -> S_CHECK
            --  - Si attempts=0 y no hay reload_pending => ir a LOCK
            ----------------------------------------------------------------
            when S_VERIFY =>
                -- IMPORTANTE: si attempts=0 pero acabamos de volver de LOCK/CONFIG,
                -- darle 1 ciclo de gracia para que el contador recargue.
                if (attempts = "00") and (reload_pending = '0') then
                    state_next <= S_LOCK;
                elsif btn_cfg_p = '1' then
                    state_next <= S_CONFIG;
                elsif btn_ok_p = '1' then
                    state_next <= S_CHECK;
                else
                    state_next <= S_VERIFY;
                end if;

            when S_CHECK =>
                if match = '1' then
                    state_next <= S_DONE;
                else
                    state_next <= S_VERIFY;
                end if;

            when S_LOCK =>
                if timer_done = '1' then
                    state_next <= S_VERIFY;
                else
                    state_next <= S_LOCK;
                end if;

            when S_DONE =>
                state_next <= S_DONE;
        end case;
    end process;

    ----------------------------------------------------------------
    -- Salidas
    ----------------------------------------------------------------
    access_granted <= '1' when state_reg = S_DONE else '0';
    lock_active    <= '1' when state_reg = S_LOCK else '0';
    attempts_left  <= attempts;
    remaining_sec  <= rem_secs;

    with state_reg select
        state_debug <= "000" when S_CONFIG,
                       "001" when S_VERIFY,
                       "010" when S_CHECK,
                       "011" when S_LOCK,
                       "100" when S_DONE,
                       "111" when others;

end Behavioral;

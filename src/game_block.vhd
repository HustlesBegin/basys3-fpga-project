library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_block is
    Port (
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        game_en     : in  STD_LOGIC;                    -- 1 => juego habilitado (auth OK)
        btn_try_p   : in  STD_LOGIC;                    -- pulso de intento (BTNC filtrado)
        sw_guess    : in  STD_LOGIC_VECTOR(3 downto 0); -- switches con el número a adivinar
        tick_1hz    : in  STD_LOGIC;                    -- de clk_divider

        attempts_left : out unsigned(2 downto 0);       -- 0..5
        lock_active   : out STD_LOGIC;                  -- 1 => bloqueo 15 s
        remaining_sec : out unsigned(4 downto 0);       -- 0..15 (para cuenta regresiva)
        msg_code      : out STD_LOGIC_VECTOR(1 downto 0); -- 00: nada, 01: SUBE, 10: BAJA, 11: OH
        state_debug   : out STD_LOGIC_VECTOR(2 downto 0)  -- debug FSM juego
    );
end game_block;

architecture Behavioral of game_block is

    ----------------------------------------------------------------
    -- Estados del juego
    ----------------------------------------------------------------
    type g_state_type is (
        G_IDLE,       -- espera game_en=1
        G_NEW_ROUND,  -- genera y fija número objetivo, reinicia intentos
        G_WAIT_GUESS, -- espera intento del usuario
        G_CHECK,      -- compara intento vs objetivo
        G_WIN,        -- acierto
        G_FAIL_MSG,   -- mostrar FAIL 3 s
        G_FAIL_LOCK   -- bloqueo 15 s
    );

    signal state_reg, state_next : g_state_type;
    signal state_prev            : g_state_type;

    ----------------------------------------------------------------
    -- Número objetivo (LFSR) y comparador
    ----------------------------------------------------------------
    signal lfsr_val   : STD_LOGIC_VECTOR(3 downto 0);
    signal target_num : STD_LOGIC_VECTOR(3 downto 0);

    signal cmp_lt, cmp_gt, cmp_eq : STD_LOGIC;

    ----------------------------------------------------------------
    -- Intentos (5 por ronda)
    ----------------------------------------------------------------
    signal attempts     : unsigned(2 downto 0) := "101"; -- 5
    signal attempts_nxt : unsigned(2 downto 0);

    ----------------------------------------------------------------
    -- Mensaje SUBE/BAJA/OH
    ----------------------------------------------------------------
    signal msg_reg : STD_LOGIC_VECTOR(1 downto 0) := "00";

    ----------------------------------------------------------------
    -- Temporizadores: 3 s FAIL + 15 s bloqueo
    ----------------------------------------------------------------
    signal t3_start,  t3_active,  t3_done  : STD_LOGIC;
    signal t15_start, t15_active, t15_done : STD_LOGIC;
    signal dummy3  : unsigned(5 downto 0);
    signal rem15   : unsigned(5 downto 0);

begin

    ----------------------------------------------------------------
    -- LFSR pseudoaleatorio (rnd4_lfsr)
    -- Lo dejamos corriendo todo el tiempo (enable => '1') para que
    -- su valor cambie continuamente y la captura al iniciar ronda
    -- dependa del instante en que se entra a G_NEW_ROUND.
    ----------------------------------------------------------------
    lfsr_inst : entity work.rnd4_lfsr
        port map (
            clk    => clk,
            rst    => rst,
            enable => '1',         -- corre siempre
            rnd    => lfsr_val
        );

    ----------------------------------------------------------------
    -- Comparador intento vs objetivo
    ----------------------------------------------------------------
    cmp_inst : entity work.game_comparator
        port map (
            guess  => sw_guess,
            target => target_num,
            lt     => cmp_lt,
            gt     => cmp_gt,
            eq     => cmp_eq
        );

    ----------------------------------------------------------------
    -- Temporizador 3 s (FAIL)
    ----------------------------------------------------------------
    timer3_inst : entity work.sec_timer
        generic map (SECONDS => 3)
        port map (
            clk_1hz   => tick_1hz,
            rst       => rst,
            start     => t3_start,
            active    => t3_active,
            done      => t3_done,
            remaining => dummy3
        );

    t3_start <= '1' when (state_reg = G_FAIL_MSG and t3_active = '0' and t3_done = '0')
                else '0';

    ----------------------------------------------------------------
    -- Temporizador 15 s (bloqueo del juego)
    ----------------------------------------------------------------
    timer15_inst : entity work.sec_timer
        generic map (SECONDS => 15)
        port map (
            clk_1hz   => tick_1hz,
            rst       => rst,
            start     => t15_start,
            active    => t15_active,
            done      => t15_done,
            remaining => rem15
        );

    t15_start <= '1' when (state_reg = G_FAIL_LOCK and t15_active = '0' and t15_done = '0')
                 else '0';

    ----------------------------------------------------------------
    -- Registro de estado + estado previo + intentos
    ----------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            state_reg  <= G_IDLE;
            state_prev <= G_IDLE;
            attempts   <= "101";  -- 5
        elsif rising_edge(clk) then
            state_prev <= state_reg;
            state_reg  <= state_next;
            attempts   <= attempts_nxt;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Latch del número objetivo al entrar a G_NEW_ROUND
    -- Aquí se toma un "snapshot" del LFSR y se congela en target_num
    -- para toda la ronda. Si por alguna razón llega 0000, lo forzamos a 0001.
    ----------------------------------------------------------------
    process(clk, rst)
        variable lfsr_u : unsigned(3 downto 0);
    begin
        if rst = '1' then
            target_num <= "0001";
        elsif rising_edge(clk) then
            if (state_prev /= G_NEW_ROUND) and (state_reg = G_NEW_ROUND) then
                -- tomar valor actual del LFSR; si es 0000, forzar 0001
                lfsr_u := unsigned(lfsr_val);
                if lfsr_u = 0 then
                    target_num <= "0001";
                else
                    target_num <= std_logic_vector(lfsr_u);
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- FSM del juego + manejo de intentos (combinacional)
    ----------------------------------------------------------------
    process(state_reg, game_en, btn_try_p, cmp_eq, cmp_lt, cmp_gt,
            attempts, t3_done, t15_done)
    begin
        -- valores por defecto
        state_next    <= state_reg;
        attempts_nxt  <= attempts;

        case state_reg is

            ----------------------------------------------------------------
            -- G_IDLE: espera a que game_en=1 (auth OK)
            ----------------------------------------------------------------
            when G_IDLE =>
                if game_en = '1' then
                    attempts_nxt <= "101"; -- 5 intentos por ronda
                    state_next   <= G_NEW_ROUND;
                else
                    state_next   <= G_IDLE;
                end if;

            ----------------------------------------------------------------
            -- G_NEW_ROUND: ya se latchó target_num en el proceso anterior
            ----------------------------------------------------------------
            when G_NEW_ROUND =>
                attempts_nxt <= "101";     -- reset intentos
                state_next   <= G_WAIT_GUESS;

            ----------------------------------------------------------------
            -- G_WAIT_GUESS: espera pulso de intento del usuario
            ----------------------------------------------------------------
            when G_WAIT_GUESS =>
                if game_en = '0' then
                    state_next <= G_IDLE;
                elsif btn_try_p = '1' then
                    state_next <= G_CHECK;
                else
                    state_next <= G_WAIT_GUESS;
                end if;

            ----------------------------------------------------------------
            -- G_CHECK: compara guess vs target y actualiza intentos
            ----------------------------------------------------------------
            when G_CHECK =>
                if cmp_eq = '1' then
                    -- acierto: no se descuenta intento
                    attempts_nxt <= attempts;
                    state_next   <= G_WIN;
                else
                    -- fallo: descontar intento
                    if attempts > "001" then
                        -- todavía quedarán intentos después
                        attempts_nxt <= attempts - 1;
                        state_next   <= G_WAIT_GUESS;
                    else
                        -- este es el último intento → derrota
                        attempts_nxt <= "000";
                        state_next   <= G_FAIL_MSG;
                    end if;
                end if;

            ----------------------------------------------------------------
            -- G_WIN: acierto
            ----------------------------------------------------------------
            when G_WIN =>
                if game_en = '0' then
                    state_next <= G_IDLE;
                else
                    state_next <= G_WIN;
                end if;

            ----------------------------------------------------------------
            -- G_FAIL_MSG: mostrar FAIL durante 3 s
            ----------------------------------------------------------------
            when G_FAIL_MSG =>
                if t3_done = '1' then
                    state_next <= G_FAIL_LOCK;
                else
                    state_next <= G_FAIL_MSG;
                end if;

            ----------------------------------------------------------------
            -- G_FAIL_LOCK: bloqueo 15 s, luego nueva ronda
            ----------------------------------------------------------------
            when G_FAIL_LOCK =>
                if t15_done = '1' then
                    attempts_nxt <= "101";   -- restaurar intentos
                    state_next   <= G_NEW_ROUND;
                else
                    state_next   <= G_FAIL_LOCK;
                end if;

        end case;
    end process;

    ----------------------------------------------------------------
    -- Registro del mensaje SUBE/BAJA/OH
    ----------------------------------------------------------------
    process(clk, rst)
    begin
        if rst = '1' then
            msg_reg <= "00";
        elsif rising_edge(clk) then
            if state_reg = G_CHECK then
                if cmp_eq = '1' then
                    msg_reg <= "11";       -- OH
                elsif cmp_lt = '1' then
                    msg_reg <= "01";       -- SUBE
                elsif cmp_gt = '1' then
                    msg_reg <= "10";       -- BAJA
                else
                    msg_reg <= "00";
                end if;
            elsif (state_reg = G_NEW_ROUND) or
                  (state_reg = G_FAIL_MSG) or
                  (state_reg = G_FAIL_LOCK) then
                -- limpiar mensaje al iniciar nueva ronda o en FAIL/BLOQUEO
                msg_reg <= "00";
            else
                msg_reg <= msg_reg;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Salidas
    ----------------------------------------------------------------
    attempts_left <= attempts;
    lock_active   <= '1' when state_reg = G_FAIL_LOCK else '0';
    remaining_sec <= rem15(4 downto 0);     -- 0..15
    msg_code      <= msg_reg;

    with state_reg select
        state_debug <= "000" when G_IDLE,
                       "001" when G_NEW_ROUND,
                       "010" when G_WAIT_GUESS,
                       "011" when G_CHECK,
                       "100" when G_WIN,
                       "101" when G_FAIL_MSG,
                       "110" when G_FAIL_LOCK,
                       "111" when others;

end Behavioral;

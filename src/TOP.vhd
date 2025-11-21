library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity TOP is
    Port (
        -- Basys3 reales que vas a activar en I/O Ports
        CLK100MHZ : in  STD_LOGIC;
        BTNC      : in  STD_LOGIC;                -- Confirmar (OK)
        BTNL      : in  STD_LOGIC;                -- Entrar/salir CONFIG
        BTNR      : in  STD_LOGIC;                -- Reset global (activo en 1)
        SW        : in  STD_LOGIC_VECTOR(3 downto 0); -- SOLO 4 switches
        LED       : out STD_LOGIC_VECTOR(15 downto 0);
        AN        : out STD_LOGIC_VECTOR(3 downto 0);
        SEG       : out STD_LOGIC_VECTOR(6 downto 0)
    );
end TOP;

architecture Structural of TOP is
    -- Relojes internos
    signal tick_1hz  : STD_LOGIC;
    signal clk_1khz  : STD_LOGIC;    -- para multiplexar display

    -- Pulsos de botones (sincronizados + 1-ciclo)
    signal btnc_q1, btnc_q2 : STD_LOGIC := '0';
    signal btnl_q1, btnl_q2 : STD_LOGIC := '0';
    signal btn_ok_p         : STD_LOGIC;
    signal btn_cfg_p        : STD_LOGIC;

    -- Señales del bloque de autenticación (Módulo 1)
    signal access_granted : STD_LOGIC;
    signal lock_active    : STD_LOGIC;
    signal attempts_left  : unsigned(1 downto 0);
    signal remaining_sec  : unsigned(5 downto 0);
    signal state_debug    : STD_LOGIC_VECTOR(2 downto 0);

    -- Señales del bloque de juego (Módulo 2)
    signal game_attempts_left : unsigned(2 downto 0);
    signal game_lock_active   : STD_LOGIC;
    signal game_remaining_sec : unsigned(4 downto 0);
    signal game_msg_code      : STD_LOGIC_VECTOR(1 downto 0);
    signal game_state_debug   : STD_LOGIC_VECTOR(2 downto 0);

    -- Mux display
    signal dig_sel    : unsigned(1 downto 0) := "00";
    signal cur_an     : STD_LOGIC_VECTOR(3 downto 0) := (others => '1'); -- ánodo común (activo en 0)
    signal cur_seg    : STD_LOGIC_VECTOR(6 downto 0) := (others => '1'); -- segmentos activos en 0

    -- Dígitos numéricos a mostrar (para countdown e info de auth)
    signal d0, d1, d2, d3 : unsigned(3 downto 0) := "1111"; -- 'F' = off

    -- Flag: ¿estamos mostrando texto del juego (SUBE/BAJA/OH/FAIL/----)?
    signal text_mode : STD_LOGIC := '0';

    -- Patrones de segmentos para letras (gfedcba, común ánodo, 0 = ON)
    constant SEG_OFF : STD_LOGIC_VECTOR(6 downto 0) := "1111111"; -- todo apagado
    constant SEG_BAR : STD_LOGIC_VECTOR(6 downto 0) := "0111111"; -- solo segmento g encendido (----)

    constant SEG_S   : STD_LOGIC_VECTOR(6 downto 0) := "0010010"; -- S
    constant SEG_U   : STD_LOGIC_VECTOR(6 downto 0) := "1000001"; -- U
    constant SEG_B   : STD_LOGIC_VECTOR(6 downto 0) := "0000011"; -- b
    constant SEG_A   : STD_LOGIC_VECTOR(6 downto 0) := "0001000"; -- A
    constant SEG_E   : STD_LOGIC_VECTOR(6 downto 0) := "0000110"; -- E
    constant SEG_J   : STD_LOGIC_VECTOR(6 downto 0) := "1110001"; -- J 
    constant SEG_O   : STD_LOGIC_VECTOR(6 downto 0) := "1000000"; -- O 
    constant SEG_H   : STD_LOGIC_VECTOR(6 downto 0) := "0001001"; -- H

    -- Letras para FAIL
    constant SEG_F   : STD_LOGIC_VECTOR(6 downto 0) := "0001110"; -- F 
    constant SEG_I   : STD_LOGIC_VECTOR(6 downto 0) := "1111001"; -- I 
    constant SEG_L   : STD_LOGIC_VECTOR(6 downto 0) := "1000111"; -- L 

    -- Decodificador 7-seg (común ánodo, activo en 0), 0..9 + apagado
    --  seg = "gfedcba"
    function seg7(bcd : unsigned(3 downto 0)) return STD_LOGIC_VECTOR is
        variable s : STD_LOGIC_VECTOR(6 downto 0);
    begin
        case bcd is
            -- Números 0..9
            when "0000" => s := "1000000"; -- 0
            when "0001" => s := "1111001"; -- 1
            when "0010" => s := "0100100"; -- 2
            when "0011" => s := "0110000"; -- 3
            when "0100" => s := "0011001"; -- 4
            when "0101" => s := "0010010"; -- 5
            when "0110" => s := "0000010"; -- 6
            when "0111" => s := "1111000"; -- 7
            when "1000" => s := "0000000"; -- 8
            when "1001" => s := "0010000"; -- 9

            -- Apagado
            when others => s := "1111111"; -- off
        end case;
        return s;
    end function;

begin
    ----------------------------------------------------------------
    -- Divisor de reloj: genera tick_1hz y ~1kHz para el display
    ----------------------------------------------------------------
    u_div : entity work.clk_divider
        port map (
            clk_in   => CLK100MHZ,
            rst      => BTNR,
            tick_1hz => tick_1hz,
            clk_1khz => clk_1khz
        );

    ----------------------------------------------------------------
    -- Sincronización de botones (2 FFs) + pulso 1 ciclo (flanco de subida)
    ----------------------------------------------------------------
    process(CLK100MHZ)
    begin
        if rising_edge(CLK100MHZ) then
            btnc_q1 <= BTNC;  btnc_q2 <= btnc_q1;
            btnl_q1 <= BTNL;  btnl_q2 <= btnl_q1;
        end if;
    end process;

    btn_ok_p  <= (btnc_q1 and not btnc_q2); -- pulso al subir
    btn_cfg_p <= (btnl_q1 and not btnl_q2);

    ----------------------------------------------------------------
    -- Instancia del bloque de autenticación (Módulo 1)
    ----------------------------------------------------------------
    u_auth : entity work.auth_block
        port map (
            clk            => CLK100MHZ,
            rst            => BTNR,
            btn_cfg_p      => btn_cfg_p,             -- BTNL
            btn_ok_p       => btn_ok_p,              -- BTNC
            sw_key         => SW(3 downto 0),        -- SOLO 4 switches
            tick_1hz       => tick_1hz,              -- generado interno
            access_granted => access_granted,
            lock_active    => lock_active,
            attempts_left  => attempts_left,
            remaining_sec  => remaining_sec,
            state_debug    => state_debug
        );

    ----------------------------------------------------------------
    -- Instancia del bloque de juego (Módulo 2)
    -- Se habilita sólo cuando access_granted = '1'
    ----------------------------------------------------------------
    u_game : entity work.game_block
        port map (
            clk           => CLK100MHZ,
            rst           => BTNR,
            game_en       => access_granted,         -- habilitado por auth
            btn_try_p     => btn_ok_p,               -- mismo botón BTNC
            sw_guess      => SW(3 downto 0),         -- switches como intento
            tick_1hz      => tick_1hz,

            attempts_left => game_attempts_left,
            lock_active   => game_lock_active,
            remaining_sec => game_remaining_sec,
            msg_code      => game_msg_code,
            state_debug   => game_state_debug
        );

    ----------------------------------------------------------------
    -- LEDs
    ----------------------------------------------------------------
    -- Módulo 1 (auth)
    LED(1 downto 0) <= std_logic_vector(attempts_left); -- intentos auth (0..3)
    LED(4 downto 2) <= state_debug;                     -- estado FSM auth
    LED(14)         <= access_granted;                  -- acceso concedido
    LED(15)         <= lock_active;                     -- bloqueo auth

    -- Módulo 2 (game) en bits altos
    LED(7 downto 5)  <= std_logic_vector(game_attempts_left); -- intentos juego (0..5)
    LED(10 downto 8) <= game_state_debug;                     -- estado FSM juego
    LED(13)          <= game_lock_active;                     -- bloqueo juego

    -- Cualquier LED no usado lo dejamos en 0
    LED(12 downto 11) <= (others => '0');

    ----------------------------------------------------------------
    -- DIGITOS a mostrar (modo numérico o texto)
    ----------------------------------------------------------------
    process(access_granted,
            lock_active, remaining_sec, attempts_left, state_debug,
            game_lock_active, game_remaining_sec, game_msg_code, game_state_debug)
        variable sec_int   : integer;
        variable tens      : integer;
        variable ones      : integer;
    begin
        -- default: numérico off y texto apagado
        d0 <= "1111"; d1 <= "1111"; d2 <= "1111"; d3 <= "1111";
        text_mode <= '0';

        if access_granted = '0' then
            ----------------------------------------------------------------
            -- MODO AUTENTICACIÓN (Módulo 1)
            ----------------------------------------------------------------
            if lock_active = '1' then
                -- Mostrar countdown de bloqueo de 30 s (remaining_sec)
                sec_int := to_integer(remaining_sec);  -- 0..60 (usamos 0..30)
                tens    := (sec_int / 10) mod 10;
                ones    := sec_int mod 10;
                d0      <= to_unsigned(ones, 4);
                d1      <= to_unsigned(tens, 4);
                -- d2, d3 apagados (1111)
            else
                -- Modo normal auth: intentos y estado FSM
                d0 <= resize(attempts_left, 4);            -- 0..3
                d1 <= resize(unsigned(state_debug), 4);    -- 0..7
                -- d2, d3 apagados
            end if;

        else
            ----------------------------------------------------------------
            -- MODO JUEGO (Módulo 2)
            ----------------------------------------------------------------
            if game_lock_active = '1' then
                -- Mostrar countdown de bloqueo del juego (15 s) en modo numérico
                sec_int := to_integer(game_remaining_sec);  -- 0..15
                tens    := (sec_int / 10) mod 10;
                ones    := sec_int mod 10;
                d0      <= to_unsigned(ones, 4);
                d1      <= to_unsigned(tens, 4);
                text_mode <= '0';   -- aquí usamos números
            else
                -- NO estamos en bloqueo => siempre modo texto:
                --   - G_FAIL_MSG (game_state_debug="101") -> FAIL
                --   - msg_code="01" -> SUBE
                --   - msg_code="10" -> BAJA
                --   - msg_code="11" -> OH
                --   - msg_code="00" -> "----" (segmento G en los 4)
                text_mode <= '1';
                -- d0..d3 se ignoran en modo texto
            end if;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Multiplexor de displays a ~1kHz
    ----------------------------------------------------------------
    process(clk_1khz)
    begin
        if rising_edge(clk_1khz) then
            dig_sel <= dig_sel + 1;
        end if;
    end process;

    -- Selección de dígito actual:
    --  - Si text_mode=0 -> usar d0..d3 + seg7 (modo numérico)
    --  - Si text_mode=1 -> ignorar d* y escribir letras SUBE/BAJA/OH/FAIL/---- directo
    process(dig_sel, d0, d1, d2, d3,
            text_mode, game_msg_code, game_state_debug)
        variable seg_val : STD_LOGIC_VECTOR(6 downto 0);
    begin
        if text_mode = '1' then
            ------------------------------------------------------------
            -- MODO TEXTO (solo cuando access_granted=1 y no hay bloqueo juego)
            --
            -- G_FAIL_MSG (state_debug="101")  -> FAIL
            -- msg_code="01"                  -> SUBE
            -- msg_code="10"                  -> BAJA
            -- msg_code="11"                  -> OH
            -- msg_code="00"                  -> "----" (línea horizontal)
            ------------------------------------------------------------
            if game_state_debug = "101" then
                -- Estado G_FAIL_MSG => FAIL
                case dig_sel is
                    when "00" =>  -- dígito derecho (AN0)
                        cur_an  <= "1110";
                        seg_val := SEG_L;   -- FAIL: L
                    when "01" =>  -- AN1
                        cur_an  <= "1101";
                        seg_val := SEG_I;   -- FAIL: I
                    when "10" =>  -- AN2
                        cur_an  <= "1011";
                        seg_val := SEG_A;   -- FAIL: A
                    when others => -- "11" -> AN3 (izquierdo)
                        cur_an  <= "0111";
                        seg_val := SEG_F;   -- FAIL: F
                end case;
            else
                -- Otros estados de juego: usar msg_code para SUBE / BAJA / OH / "----"
                case dig_sel is
                    when "00" =>  -- dígito derecho (AN0)
                        cur_an <= "1110";
                        case game_msg_code is
                            when "01" => seg_val := SEG_E;       -- SUBE: E
                            when "10" => seg_val := SEG_A;       -- BAJA: A
                            when "11" => seg_val := SEG_OFF;     -- OH: espacio
                            when others => seg_val := SEG_BAR;   -- "----": barra
                        end case;

                    when "01" =>  -- AN1
                        cur_an <= "1101";
                        case game_msg_code is
                            when "01" => seg_val := SEG_B;       -- SUBE: B
                            when "10" => seg_val := SEG_J;       -- BAJA: J
                            when "11" => seg_val := SEG_H;       -- OH: H
                            when others => seg_val := SEG_BAR;   -- "----"
                        end case;

                    when "10" =>  -- AN2
                        cur_an <= "1011";
                        case game_msg_code is
                            when "01" => seg_val := SEG_U;       -- SUBE: U
                            when "10" => seg_val := SEG_A;       -- BAJA: A
                            when "11" => seg_val := SEG_O;       -- OH: O
                            when others => seg_val := SEG_BAR;   -- "----"
                        end case;

                    when others => -- "11" -> AN3
                        cur_an <= "0111";
                        case game_msg_code is
                            when "01" => seg_val := SEG_S;       -- SUBE: S
                            when "10" => seg_val := SEG_B;       -- BAJA: B
                            when "11" => seg_val := SEG_OFF;     -- OH: espacio
                            when others => seg_val := SEG_BAR;   -- "----"
                        end case;
                end case;
            end if;

            cur_seg <= seg_val;

        else
            ------------------------------------------------------------
            -- MODO NUMÉRICO (auth + countdowns)
            ------------------------------------------------------------
            case dig_sel is
                when "00" => cur_an <= "1110"; cur_seg <= seg7(d0);
                when "01" => cur_an <= "1101"; cur_seg <= seg7(d1);
                when "10" => cur_an <= "1011"; cur_seg <= seg7(d2);
                when others => cur_an <= "0111"; cur_seg <= seg7(d3);
            end case;
        end if;
    end process;

    AN  <= cur_an;
    SEG <= cur_seg;

end Structural;

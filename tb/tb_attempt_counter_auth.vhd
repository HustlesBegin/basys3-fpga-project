library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_attempt_counter_auth is
end tb_attempt_counter_auth;

architecture sim of tb_attempt_counter_auth is

    -- Senales del testbench
    signal tb_clk           : STD_LOGIC := '0';
    signal tb_rst           : STD_LOGIC := '0';
    signal tb_new_try       : STD_LOGIC := '0';
    signal tb_success       : STD_LOGIC := '0';
    signal tb_reload        : STD_LOGIC := '0';
    signal tb_attempts_left : unsigned(1 downto 0);
    signal tb_locked        : STD_LOGIC;

    constant TB_CLK_PERIOD : time := 10 ns;  -- periodo del reloj del tb

begin

    --------------------------------------------------------------------
    -- Generador de reloj
    --------------------------------------------------------------------
    tb_clk_process : process
    begin
        tb_clk <= '0';
        wait for TB_CLK_PERIOD/2;
        tb_clk <= '1';
        wait for TB_CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Instancia del DUT (attempt_counter_auth)
    --------------------------------------------------------------------
    dut : entity work.attempt_counter_auth
        port map (
            clk           => tb_clk,
            rst           => tb_rst,
            new_try       => tb_new_try,
            success       => tb_success,
            reload        => tb_reload,
            attempts_left => tb_attempts_left,
            locked        => tb_locked
        );

    --------------------------------------------------------------------
    -- Estimulos de prueba
    --------------------------------------------------------------------
    stim_proc : process
    begin
        report "=== INICIO SIMULACION attempt_counter_auth ===";

        ----------------------------------------------------------------
        -- RESET INICIAL
        ----------------------------------------------------------------
        tb_rst     <= '1';
        tb_new_try <= '0';
        tb_success <= '0';
        tb_reload  <= '0';
        wait for 3 * TB_CLK_PERIOD;

        tb_rst <= '0';
        report "Reset liberado. attempts_left debe ser 3, locked=0" severity note;
        wait for 2 * TB_CLK_PERIOD;

        ----------------------------------------------------------------
        -- ESCENARIO 1: tres intentos fallidos seguidos
        ----------------------------------------------------------------
        report "--- ESCENARIO 1: tres intentos fallidos ---" severity note;

        -- Intento 1 fallido
        tb_success <= '0';
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        -- Intento 2 fallido
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        -- Intento 3 fallido
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        report "Tras 3 intentos fallidos: attempts_left="
               & integer'image(to_integer(tb_attempts_left))
               & " locked=" & std_logic'image(tb_locked) severity note;

        wait for 3 * TB_CLK_PERIOD;

        ----------------------------------------------------------------
        -- ESCENARIO 2: recarga externa con reload
        ----------------------------------------------------------------
        report "--- ESCENARIO 2: recarga con reload ---" severity note;

        tb_reload <= '1';
        wait for TB_CLK_PERIOD;
        tb_reload <= '0';
        wait for TB_CLK_PERIOD;

        report "Tras reload=1: attempts_left="
               & integer'image(to_integer(tb_attempts_left))
               & " locked=" & std_logic'image(tb_locked) severity note;

        wait for 3 * TB_CLK_PERIOD;

        ----------------------------------------------------------------
        -- ESCENARIO 3: intento exitoso que recarga a 3
        ----------------------------------------------------------------
        report "--- ESCENARIO 3: intento exitoso (success=1) ---" severity note;

        -- Primero consumir un intento para ver el cambio
        tb_success <= '0';
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        report "Despues de 1 intento fallido: attempts_left="
               & integer'image(to_integer(tb_attempts_left)) severity note;

        -- Ahora intento exitoso
        tb_success <= '1';
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        tb_success <= '0';
        wait for TB_CLK_PERIOD;

        report "Tras intento exitoso: attempts_left="
               & integer'image(to_integer(tb_attempts_left))
               & " locked=" & std_logic'image(tb_locked) severity note;

        ----------------------------------------------------------------
        -- ESCENARIO 4: intentar restar cuando ya esta en 0
        ----------------------------------------------------------------
        report "--- ESCENARIO 4: forzar de nuevo hasta 0 y verificar bloqueo ---" severity note;

        -- Bajar a 0 otra vez
        tb_success <= '0';

        tb_new_try <= '1';  -- 1
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        tb_new_try <= '1';  -- 2
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        tb_new_try <= '1';  -- 3
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        report "De nuevo en 0: attempts_left="
               & integer'image(to_integer(tb_attempts_left))
               & " locked=" & std_logic'image(tb_locked) severity note;

        -- Intento extra cuando ya esta en 0
        tb_new_try <= '1';
        wait for TB_CLK_PERIOD;
        tb_new_try <= '0';
        wait for TB_CLK_PERIOD;

        report "Intento extra con contador en 0 (no debe ir negativo): attempts_left="
               & integer'image(to_integer(tb_attempts_left))
               & " locked=" & std_logic'image(tb_locked) severity note;

        report "=== FIN SIMULACION attempt_counter_auth ===";
        wait;
    end process;

end sim;

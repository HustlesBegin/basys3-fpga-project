library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_game_block is
end tb_game_block;

architecture sim of tb_game_block is

    -- Senales del testbench
    signal tb_clk          : STD_LOGIC := '0';
    signal tb_rst          : STD_LOGIC := '0';
    signal tb_game_en      : STD_LOGIC := '0';
    signal tb_btn_try_p    : STD_LOGIC := '0';
    signal tb_sw_guess     : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_tick_1hz     : STD_LOGIC := '0';

    signal tb_attempts_left : unsigned(2 downto 0);
    signal tb_lock_active   : STD_LOGIC;
    signal tb_remaining_sec : unsigned(4 downto 0);
    signal tb_msg_code      : STD_LOGIC_VECTOR(1 downto 0);
    signal tb_state_debug   : STD_LOGIC_VECTOR(2 downto 0);

    -- Periodos de reloj (acelerados para simulacion)
    constant TB_CLK_PERIOD  : time := 10 ns;  -- reloj principal
    constant TB_TICK_PERIOD : time := 50 ns;  -- "1 Hz" acelerado

begin

    --------------------------------------------------------------------
    -- Generador de reloj principal
    --------------------------------------------------------------------
    tb_clk_proc : process
    begin
        tb_clk <= '0';
        wait for TB_CLK_PERIOD/2;
        tb_clk <= '1';
        wait for TB_CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Generador de tick_1hz acelerado
    --------------------------------------------------------------------
    tb_tick_proc : process
    begin
        tb_tick_1hz <= '0';
        wait for TB_TICK_PERIOD/2;
        tb_tick_1hz <= '1';
        wait for TB_TICK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Instancia del modulo game_block (DUT)
    --------------------------------------------------------------------
    tb_dut : entity work.game_block
        port map (
            clk           => tb_clk,
            rst           => tb_rst,
            game_en       => tb_game_en,
            btn_try_p     => tb_btn_try_p,
            sw_guess      => tb_sw_guess,
            tick_1hz      => tb_tick_1hz,
            attempts_left => tb_attempts_left,
            lock_active   => tb_lock_active,
            remaining_sec => tb_remaining_sec,
            msg_code      => tb_msg_code,
            state_debug   => tb_state_debug
        );

    --------------------------------------------------------------------
    -- Estimulos del testbench
    --------------------------------------------------------------------
    tb_stim_proc : process
        -- tarea local para generar un pulso de intento
        procedure tb_pulse_try is
        begin
            tb_btn_try_p <= '1';
            wait for TB_CLK_PERIOD;
            tb_btn_try_p <= '0';
        end procedure;
    begin
        report "=== INICIO SIMULACION game_block ===" severity note;

        ----------------------------------------------------------------
        -- RESET INICIAL
        ----------------------------------------------------------------
        report "Prueba 0: aplicar reset" severity note;
        tb_rst <= '1';
        tb_game_en <= '0';
        wait for 40 ns;
        tb_rst <= '0';
        wait for 40 ns;

        ----------------------------------------------------------------
        -- ESCENARIO 1: habilitar juego y hacer intentos fallidos
        --   Objetivo: ver flujo G_IDLE -> G_NEW_ROUND -> G_WAIT_GUESS,
        --             consumo de intentos y paso a G_FAIL_MSG / G_FAIL_LOCK.
        ----------------------------------------------------------------
        report "Escenario 1: habilitar juego y hacer 5 intentos fallidos" severity note;

        -- Habilitar juego (simula que auth_block ya dio acceso)
        tb_game_en <= '1';
        wait for 100 ns;  -- tiempo para que pase a G_NEW_ROUND y luego a G_WAIT_GUESS

        -- Intento 1: valor arbitrario (no sabemos el target, solo queremos actividad)
        tb_sw_guess <= "0000";
        tb_pulse_try;
        wait for 80 ns;

        -- Intento 2
        tb_sw_guess <= "0001";
        tb_pulse_try;
        wait for 80 ns;

        -- Intento 3
        tb_sw_guess <= "0010";
        tb_pulse_try;
        wait for 80 ns;

        -- Intento 4
        tb_sw_guess <= "0011";
        tb_pulse_try;
        wait for 80 ns;

        -- Intento 5 (deberia dejar attempts en 0 y entrar a G_FAIL_MSG)
        tb_sw_guess <= "0100";
        tb_pulse_try;
        wait for 100 ns;

        report "Despues del ultimo intento fallido, revisar state_debug y msg_code" severity note;

        ----------------------------------------------------------------
        -- Esperar los 3 segundos simulados de FAIL (G_FAIL_MSG)
        ----------------------------------------------------------------
        report "Esperando tiempo de FAIL (3 ticks acelerados)..." severity note;
        wait for TB_TICK_PERIOD * 6;  -- margen extra

        report "Revisar que se haya pasado a estado de bloqueo G_FAIL_LOCK" severity note;

        ----------------------------------------------------------------
        -- Esperar los 15 segundos simulados de bloqueo
        ----------------------------------------------------------------
        report "Esperando tiempo de bloqueo (15 ticks acelerados)..." severity note;
        wait for TB_TICK_PERIOD * 20;  -- margen extra

        report "Despues del bloqueo deberia iniciar una nueva ronda (G_NEW_ROUND)" severity note;

        ----------------------------------------------------------------
        -- ESCENARIO 2: deshabilitar el juego
        ----------------------------------------------------------------
        report "Escenario 2: apagar game_en para volver a G_IDLE" severity note;
        tb_game_en <= '0';
        wait for 100 ns;

        report "Revisar que state_debug vuelva a G_IDLE" severity note;

        ----------------------------------------------------------------
        report "=== FIN SIMULACION game_block ===" severity note;
        wait;
    end process;

end sim;

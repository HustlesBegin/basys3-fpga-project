library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_sec_timer is
end tb_sec_timer;

architecture sim of tb_sec_timer is

    -- Senales del testbench
    signal tb_clk_1hz   : STD_LOGIC := '0';
    signal tb_rst       : STD_LOGIC := '0';
    signal tb_start     : STD_LOGIC := '0';
    signal tb_active    : STD_LOGIC;
    signal tb_done      : STD_LOGIC;
    signal tb_remaining : unsigned(5 downto 0);

    -- Periodo del "clk_1hz" en simulacion (aqui acelerado)
    constant TB_TICK_PERIOD : time := 10 ns;  -- cada 10 ns hay un "segundo" simulado

begin

    --------------------------------------------------------------------
    -- Generador de reloj de 1 Hz (acelerado)
    -- En hardware real vendria del clk_divider.
    --------------------------------------------------------------------
    tb_clk_process : process
    begin
        tb_clk_1hz <= '0';
        wait for TB_TICK_PERIOD/2;
        tb_clk_1hz <= '1';
        wait for TB_TICK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Instancia del temporizador con pocos segundos para simular rapido
    --------------------------------------------------------------------
    dut : entity work.sec_timer
        generic map (
            SECONDS => 5       -- cuenta regresiva de 5 "segundos" simulados
        )
        port map (
            clk_1hz   => tb_clk_1hz,
            rst       => tb_rst,
            start     => tb_start,
            active    => tb_active,
            done      => tb_done,
            remaining => tb_remaining
        );

    --------------------------------------------------------------------
    -- Estimulos de prueba
    --------------------------------------------------------------------
    stim_proc : process
    begin
        report "=== INICIO SIMULACION sec_timer ===";

        -- Reset inicial
        tb_rst   <= '1';
        tb_start <= '0';
        wait for 30 ns;
        tb_rst <= '0';
        report "Reset liberado. El temporizador debe estar inactivo." severity note;

        -- Esperar un par de ticks sin arrancar
        wait for TB_TICK_PERIOD * 3;

        -- Arrancar el temporizador con un pulso de start
        report "Lanzando temporizador (start pulso)..." severity note;
        tb_start <= '1';
        wait for TB_TICK_PERIOD;      -- un ciclo de clk_1hz
        tb_start <= '0';

        -- Esperar suficiente tiempo para que llegue a cero
        wait for TB_TICK_PERIOD * 10;

        report "Fin de la primera cuenta regresiva." severity note;

        -- Probar un segundo arranque
        report "Lanzando de nuevo el temporizador..." severity note;
        tb_start <= '1';
        wait for TB_TICK_PERIOD;
        tb_start <= '0';

        wait for TB_TICK_PERIOD * 10;

        report "=== FIN SIMULACION sec_timer ===";
        wait;
    end process;

end sim;

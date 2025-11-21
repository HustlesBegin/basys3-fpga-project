library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_key_storage is
end tb_key_storage;

architecture sim of tb_key_storage is

    -- Senales del testbench
    signal tb_clk     : STD_LOGIC := '0';
    signal tb_rst     : STD_LOGIC := '0';
    signal tb_load_en : STD_LOGIC := '0';
    signal tb_key_in  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_key_out : STD_LOGIC_VECTOR(3 downto 0);

    constant TB_CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------------------------
    -- Generador de reloj
    --------------------------------------------------------------------
    tb_clk_proc : process
    begin
        tb_clk <= '0';
        wait for TB_CLK_PERIOD/2;
        tb_clk <= '1';
        wait for TB_CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Instancia del modulo key_storage
    --------------------------------------------------------------------
    tb_dut : entity work.key_storage
        port map (
            clk     => tb_clk,
            rst     => tb_rst,
            load_en => tb_load_en,
            key_in  => tb_key_in,
            key_out => tb_key_out
        );

    --------------------------------------------------------------------
    -- Estimulos del testbench
    --------------------------------------------------------------------
    tb_stim_proc : process
    begin
        report "=== INICIO SIMULACION key_storage ===" severity note;

        ----------------------------------------------------------------
        -- PRUEBA 1: Reset
        ----------------------------------------------------------------
        report "Prueba 1: aplicar reset" severity note;

        tb_rst <= '1';
        wait for 20 ns;
        tb_rst <= '0';
        wait for 20 ns;

        report "Fin de Prueba 1: revisar tb_key_out en la waveform" severity note;

        ----------------------------------------------------------------
        -- PRUEBA 2: Cargar clave 1010
        ----------------------------------------------------------------
        report "Prueba 2: cargar clave 1010" severity note;

        tb_key_in  <= "1010";
        tb_load_en <= '1';
        wait for TB_CLK_PERIOD;
        tb_load_en <= '0';
        wait for 20 ns;

        report "Fin de Prueba 2: tb_key_out deberia ser 1010" severity note;

        ----------------------------------------------------------------
        -- PRUEBA 3: Cambiar key_in pero SIN load_en
        ----------------------------------------------------------------
        report "Prueba 3: cambiar key_in a 0101 sin load_en" severity note;

        tb_key_in <= "0101";
        wait for 30 ns;

        report "Fin de Prueba 3: tb_key_out deberia seguir en 1010" severity note;

        ----------------------------------------------------------------
        -- PRUEBA 4: Cargar nueva clave 1111
        ----------------------------------------------------------------
        report "Prueba 4: cargar clave 1111" severity note;

        tb_key_in  <= "1111";
        tb_load_en <= '1';
        wait for TB_CLK_PERIOD;
        tb_load_en <= '0';
        wait for 20 ns;

        report "Fin de Prueba 4: tb_key_out deberia ser 1111" severity note;

        ----------------------------------------------------------------
        report "=== FIN SIMULACION key_storage ===" severity note;
        wait;
    end process;

end sim;

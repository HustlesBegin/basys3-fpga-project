library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_rnd4_lfsr is
end tb_rnd4_lfsr;

architecture sim of tb_rnd4_lfsr is

    -- Senales del testbench
    signal tb_clk    : STD_LOGIC := '0';
    signal tb_rst    : STD_LOGIC := '0';
    signal tb_enable : STD_LOGIC := '0';
    signal tb_rnd    : STD_LOGIC_VECTOR(3 downto 0);

    -- Periodo de reloj
    constant TB_CLK_PERIOD : time := 10 ns;

    -- Funcion auxiliar para mostrar un std_logic_vector(3 downto 0) como string
    function tb_slv4_to_string(
        v : STD_LOGIC_VECTOR(3 downto 0)
    ) return string is
        variable s : string(1 to 4);
    begin
        -- v(3) es el bit mas significativo
        if v(3) = '0' then
            s(1) := '0';
        else
            s(1) := '1';
        end if;

        if v(2) = '0' then
            s(2) := '0';
        else
            s(2) := '1';
        end if;

        if v(1) = '0' then
            s(3) := '0';
        else
            s(3) := '1';
        end if;

        if v(0) = '0' then
            s(4) := '0';
        else
            s(4) := '1';
        end if;

        return s;
    end function;

begin

    --------------------------------------------------------------------
    -- Generador de reloj principal
    --------------------------------------------------------------------
    tb_clk_proc : process
    begin
        tb_clk <= '0';
        wait for TB_CLK_PERIOD / 2;
        tb_clk <= '1';
        wait for TB_CLK_PERIOD / 2;
    end process;

    --------------------------------------------------------------------
    -- Instancia del modulo LFSR (DUT)
    --------------------------------------------------------------------
    tb_dut : entity work.rnd4_lfsr
        port map (
            clk    => tb_clk,
            rst    => tb_rst,
            enable => tb_enable,
            rnd    => tb_rnd
        );

    --------------------------------------------------------------------
    -- Estimulos
    --------------------------------------------------------------------
    tb_stim_proc : process
        variable i : integer;
    begin
        report "=== INICIO SIMULACION rnd4_lfsr ===" severity note;

        ----------------------------------------------------------------
        -- Reset inicial
        ----------------------------------------------------------------
        tb_rst    <= '1';
        tb_enable <= '0';
        wait for 50 ns;

        tb_rst <= '0';
        report "Reset aplicado. LFSR deberia iniciar en semilla tb_rnd" severity note;
        wait for TB_CLK_PERIOD * 2;
        report "Valor inicial tb_rnd = " & tb_slv4_to_string(tb_rnd) severity note;

        ----------------------------------------------------------------
        -- Habilitar LFSR y registrar varios valores en el log
        ----------------------------------------------------------------
        report "Habilitando LFSR. Mostrando varios valores de tb_rnd en el log" severity note;
        tb_enable <= '1';

        for i in 0 to 20 loop
            wait until rising_edge(tb_clk);
            report "Ciclo " & integer'image(i) &
                   " -> tb_rnd = " & tb_slv4_to_string(tb_rnd) severity note;
        end loop;

        ----------------------------------------------------------------
        -- Deshabilitar LFSR para ver valor congelado
        ----------------------------------------------------------------
        tb_enable <= '0';
        report "LFSR deshabilitado. Valor deberia permanecer constante" severity note;

        for i in 21 to 26 loop
            wait until rising_edge(tb_clk);
            report "Ciclo " & integer'image(i) &
                   " (enable=0) -> tb_rnd = " & tb_slv4_to_string(tb_rnd) severity note;
        end loop;

        report "=== FIN SIMULACION rnd4_lfsr ===" severity note;
        wait;
    end process;

end sim;

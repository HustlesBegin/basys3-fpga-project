library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_key_checker is
end tb_key_checker;

architecture sim of tb_key_checker is

    -- Senales del testbench
    signal tb_key_try  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_key_real : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_match    : STD_LOGIC;

begin

    --------------------------------------------------------------------
    -- Instancia del modulo key_checker (DUT)
    --------------------------------------------------------------------
    dut : entity work.key_checker
        port map (
            key_try  => tb_key_try,
            key_real => tb_key_real,
            match    => tb_match
        );

    --------------------------------------------------------------------
    -- Estimulos del testbench
    --------------------------------------------------------------------
    stim_proc : process
    begin
        report "=== INICIO SIMULACION key_checker ===";

        ------------------------------------------------------------
        -- PRUEBA 1: Igualdad exacta
        ------------------------------------------------------------
        tb_key_real <= "1010";
        tb_key_try  <= "1010";
        wait for 20 ns;

        report "Prueba 1: key_try=1010, key_real=1010 -> match="
               & std_logic'image(tb_match) severity note;

        ------------------------------------------------------------
        -- PRUEBA 2: Valor incorrecto
        ------------------------------------------------------------
        tb_key_try <= "0011";
        wait for 20 ns;

        report "Prueba 2: key_try=0011, key_real=1010 -> match="
               & std_logic'image(tb_match) severity note;

        ------------------------------------------------------------
        -- PRUEBA 3: Cambios dinamicos
        ------------------------------------------------------------
        tb_key_try  <= "1111";
        tb_key_real <= "1111";
        wait for 20 ns;

        report "Prueba 3: key_try=1111, key_real=1111 -> match="
               & std_logic'image(tb_match) severity note;

        tb_key_try <= "0000";
        wait for 20 ns;

        report "Prueba 4: key_try=0000, key_real=1111 -> match="
               & std_logic'image(tb_match) severity note;

        ------------------------------------------------------------
        report "=== FIN SIMULACION key_checker ===";
        wait;
    end process;

end sim;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;  -- Necesario para to_unsigned

entity tb_game_comparator is
end tb_game_comparator;

architecture sim of tb_game_comparator is

    -- Senales del testbench
    signal tb_guess  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_target : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_lt     : STD_LOGIC;
    signal tb_gt     : STD_LOGIC;
    signal tb_eq     : STD_LOGIC;

    -- Funcion auxiliar para imprimir vectores en la consola
    function tb_slv4_to_str(v : STD_LOGIC_VECTOR(3 downto 0)) return string is
        variable s : string(1 to 4);
    begin
        if v(3) = '0' then s(1) := '0'; else s(1) := '1'; end if;
        if v(2) = '0' then s(2) := '0'; else s(2) := '1'; end if;
        if v(1) = '0' then s(3) := '0'; else s(3) := '1'; end if;
        if v(0) = '0' then s(4) := '0'; else s(4) := '1'; end if;
        return s;
    end function;

begin

    --------------------------------------------------------------------
    -- Instancia del modulo game_comparator (DUT)
    --------------------------------------------------------------------
    tb_dut : entity work.game_comparator
        port map (
            guess  => tb_guess,
            target => tb_target,
            lt     => tb_lt,
            gt     => tb_gt,
            eq     => tb_eq
        );

    --------------------------------------------------------------------
    -- Estimulos
    --------------------------------------------------------------------
    tb_stim : process
    begin
        report "=== INICIO SIMULACION game_comparator ===" severity note;

        ----------------------------------------------------------------
        -- Prueba 1: igualdad
        ----------------------------------------------------------------
        tb_guess  <= "0101";  -- 5
        tb_target <= "0101";  -- 5
        wait for 20 ns;

        report "Test 1 (igual): guess=" & tb_slv4_to_str(tb_guess) &
               " target=" & tb_slv4_to_str(tb_target) &
               " -> lt=" & STD_LOGIC'IMAGE(tb_lt) &
               " gt=" & STD_LOGIC'IMAGE(tb_gt) &
               " eq=" & STD_LOGIC'IMAGE(tb_eq) severity note;

        ----------------------------------------------------------------
        -- Prueba 2: guess < target
        ----------------------------------------------------------------
        tb_guess  <= "0011"; -- 3
        tb_target <= "1000"; -- 8
        wait for 20 ns;

        report "Test 2 (menor): guess=" & tb_slv4_to_str(tb_guess) &
               " target=" & tb_slv4_to_str(tb_target) &
               " -> lt=" & STD_LOGIC'IMAGE(tb_lt) &
               " gt=" & STD_LOGIC'IMAGE(tb_gt) &
               " eq=" & STD_LOGIC'IMAGE(tb_eq) severity note;

        ----------------------------------------------------------------
        -- Prueba 3: guess > target
        ----------------------------------------------------------------
        tb_guess  <= "1110"; -- 14
        tb_target <= "0100"; -- 4
        wait for 20 ns;

        report "Test 3 (mayor): guess=" & tb_slv4_to_str(tb_guess) &
               " target=" & tb_slv4_to_str(tb_target) &
               " -> lt=" & STD_LOGIC'IMAGE(tb_lt) &
               " gt=" & STD_LOGIC'IMAGE(tb_gt) &
               " eq=" & STD_LOGIC'IMAGE(tb_eq) severity note;

        ----------------------------------------------------------------
        -- Prueba 4: varias combinaciones en secuencia
        ----------------------------------------------------------------
        for i in 0 to 10 loop
            tb_guess  <= std_logic_vector(to_unsigned(i mod 16, 4));
            tb_target <= std_logic_vector(to_unsigned((i + 5) mod 16, 4));
            wait for 20 ns;

            report "Seq Test " & integer'image(i) &
                   ": guess=" & tb_slv4_to_str(tb_guess) &
                   " target=" & tb_slv4_to_str(tb_target) &
                   " -> lt=" & STD_LOGIC'IMAGE(tb_lt) &
                   " gt=" & STD_LOGIC'IMAGE(tb_gt) &
                   " eq=" & STD_LOGIC'IMAGE(tb_eq) severity note;
        end loop;

        report "=== FIN SIMULACION game_comparator ===" severity note;
        wait;
    end process;

end sim;

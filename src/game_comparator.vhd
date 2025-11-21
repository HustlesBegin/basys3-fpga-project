library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity game_comparator is
    Port (
        guess  : in  STD_LOGIC_VECTOR(3 downto 0); -- número ingresado por el usuario
        target : in  STD_LOGIC_VECTOR(3 downto 0); -- número objetivo
        lt     : out STD_LOGIC;                    -- guess < target -> SUBE
        gt     : out STD_LOGIC;                    -- guess > target -> BAJA
        eq     : out STD_LOGIC                     -- guess = target -> OH
    );
end game_comparator;

architecture Behavioral of game_comparator is
    signal g_u : unsigned(3 downto 0);
    signal t_u : unsigned(3 downto 0);
begin
    g_u <= unsigned(guess);
    t_u <= unsigned(target);

    eq <= '1' when (g_u = t_u) else '0';
    lt <= '1' when (g_u < t_u) else '0';
    gt <= '1' when (g_u > t_u) else '0';
end Behavioral;
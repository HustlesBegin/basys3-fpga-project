library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_checker is
    Port (
        key_try   : in  STD_LOGIC_VECTOR(3 downto 0);
        key_real  : in  STD_LOGIC_VECTOR(3 downto 0);
        match     : out STD_LOGIC
    );
end key_checker;

architecture Behavioral of key_checker is
begin
    match <= '1' when key_try = key_real else '0';
end Behavioral;

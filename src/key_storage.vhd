library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity key_storage is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        load_en  : in  STD_LOGIC;               -- 1 cuando BTNC en modo config
        key_in   : in  STD_LOGIC_VECTOR(3 downto 0);
        key_out  : out STD_LOGIC_VECTOR(3 downto 0)
    );
end key_storage;

architecture Behavioral of key_storage is
    signal reg_key : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
begin
    process(clk, rst)
    begin
        if rst = '1' then
            reg_key <= (others => '0');
        elsif rising_edge(clk) then
            if load_en = '1' then
                reg_key <= key_in;
            end if;
        end if;
    end process;

    key_out <= reg_key;
end Behavioral;

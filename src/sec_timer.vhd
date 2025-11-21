library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sec_timer is
    generic (
        SECONDS : integer := 30
    );
    Port (
        clk_1hz   : in  STD_LOGIC;              -- usar tick de 1 Hz
        rst       : in  STD_LOGIC;
        start     : in  STD_LOGIC;
        active    : out STD_LOGIC;
        done      : out STD_LOGIC;
        remaining : out unsigned(5 downto 0)    -- 0..63
    );
end sec_timer;

architecture Behavioral of sec_timer is
    signal count     : unsigned(5 downto 0) := (others => '0');
    signal active_i  : STD_LOGIC := '0';
    signal done_i    : STD_LOGIC := '0';
begin
    process(clk_1hz, rst)
    begin
        if rst = '1' then
            active_i <= '0';
            done_i   <= '0';
            count    <= (others => '0');
        elsif rising_edge(clk_1hz) then
            done_i <= '0';
            if start = '1' then
                active_i <= '1';
                count    <= to_unsigned(SECONDS, count'length);
            elsif active_i = '1' then
                if count = 0 then
                    active_i <= '0';
                    done_i   <= '1';
                else
                    count <= count - 1;
                end if;
            end if;
        end if;
    end process;

    active    <= active_i;
    done      <= done_i;
    remaining <= count;

end Behavioral;

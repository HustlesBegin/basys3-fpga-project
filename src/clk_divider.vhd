library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity clk_divider is
    Port (
        clk_in     : in  STD_LOGIC;  -- 100 MHz
        rst        : in  STD_LOGIC;
        tick_1hz   : out STD_LOGIC;  -- pulso 1 vez por segundo
        clk_1khz   : out STD_LOGIC   -- ~1 kHz para el display
    );
end clk_divider;

architecture Behavioral of clk_divider is
    constant DIV_1HZ  : integer := 100_000_000;
    constant DIV_1KHZ : integer := 100_000;       -- 100 MHz / 100_000 = 1 kHz

    signal cnt_1hz    : unsigned(26 downto 0) := (others => '0');
    signal cnt_1khz   : unsigned(16 downto 0) := (others => '0');

    signal tick_1hz_i  : STD_LOGIC := '0';
    signal clk_1khz_i  : STD_LOGIC := '0';
begin

    -- Tick 1 Hz
    process(clk_in, rst)
    begin
        if rst = '1' then
            cnt_1hz   <= (others => '0');
            tick_1hz_i <= '0';
        elsif rising_edge(clk_in) then
            if cnt_1hz = DIV_1HZ - 1 then
                cnt_1hz   <= (others => '0');
                tick_1hz_i <= '1';
            else
                cnt_1hz   <= cnt_1hz + 1;
                tick_1hz_i <= '0';
            end if;
        end if;
    end process;

    -- Clock ~1 kHz
    process(clk_in, rst)
    begin
        if rst = '1' then
            cnt_1khz  <= (others => '0');
            clk_1khz_i <= '0';
        elsif rising_edge(clk_in) then
            if cnt_1khz = DIV_1KHZ/2 - 1 then
                cnt_1khz  <= (others => '0');
                clk_1khz_i <= not clk_1khz_i;
            else
                cnt_1khz <= cnt_1khz + 1;
            end if;
        end if;
    end process;

    tick_1hz <= tick_1hz_i;
    clk_1khz <= clk_1khz_i;

end Behavioral;

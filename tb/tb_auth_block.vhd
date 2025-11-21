library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_auth_block is
end tb_auth_block;

architecture sim of tb_auth_block is

    -- Testbench signals (tb_ prefix)
    signal tb_clk            : STD_LOGIC := '0';
    signal tb_rst            : STD_LOGIC := '0';
    signal tb_btn_cfg_p      : STD_LOGIC := '0';
    signal tb_btn_ok_p       : STD_LOGIC := '0';
    signal tb_sw_key         : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal tb_tick_1hz       : STD_LOGIC := '0';

    signal tb_access_granted : STD_LOGIC;
    signal tb_lock_active    : STD_LOGIC;
    signal tb_attempts_left  : unsigned(1 downto 0);
    signal tb_remaining_sec  : unsigned(5 downto 0);
    signal tb_state_debug    : STD_LOGIC_VECTOR(2 downto 0);

    constant TB_CLK_PERIOD  : time := 1 ns;   -- 100 MHz simulated
    constant TB_TICK_PERIOD : time := 10 ns;  -- "1 Hz" accelerated

begin

    --------------------------------------------------------------------
    -- Main clock generation (tb_clk)
    --------------------------------------------------------------------
    clk_process : process
    begin
        tb_clk <= '0';
        wait for TB_CLK_PERIOD/2;
        tb_clk <= '1';
        wait for TB_CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Accelerated tick_1hz generation (tb_tick_1hz)
    --------------------------------------------------------------------
    tick_process : process
    begin
        tb_tick_1hz <= '0';
        wait for TB_TICK_PERIOD/2;
        tb_tick_1hz <= '1';
        wait for TB_TICK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- DUT instance: auth_block
    --------------------------------------------------------------------
    dut : entity work.auth_block
        port map (
            clk            => tb_clk,
            rst            => tb_rst,
            btn_cfg_p      => tb_btn_cfg_p,
            btn_ok_p       => tb_btn_ok_p,
            sw_key         => tb_sw_key,
            tick_1hz       => tb_tick_1hz,
            access_granted => tb_access_granted,
            lock_active    => tb_lock_active,
            attempts_left  => tb_attempts_left,
            remaining_sec  => tb_remaining_sec,
            state_debug    => tb_state_debug
        );

    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    stim_proc : process
    begin
        ----------------------------------------------------------------
        -- INITIAL RESET
        ----------------------------------------------------------------
        report "=== TEST AUTH_BLOCK: start of simulation ===" severity note;

        tb_rst <= '1';
        wait for 50 ns;
        tb_rst <= '0';
        report "Reset applied. Expected state S_CONFIG (000)." severity note;
        wait for 50 ns;

        ----------------------------------------------------------------
        -- SCENARIO 1: configure key 1010 and then access correctly
        ----------------------------------------------------------------
        report "--- SCENARIO 1: configure key 1010 and access correctly ---" severity note;

        -- Configure key: SW = 1010, pulse BTN_OK
        tb_sw_key   <= "1010";
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';
        report "Key 1010 configured with BTNC (should go to S_VERIFY)." severity note;

        wait for 100 ns;
        report "FSM state (auth) = " &
               integer'image(to_integer(unsigned(tb_state_debug))) &
               "  Attempts = " &
               integer'image(to_integer(tb_attempts_left)) severity note;

        -- Enter the same key 1010 in VERIFY
        tb_sw_key   <= "1010";
        wait for 50 ns;
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';

        wait for 100 ns;

        report "After correct try: access_granted = " &
               std_logic'image(tb_access_granted) &
               "  FSM state = " &
               integer'image(to_integer(unsigned(tb_state_debug))) severity note;

        ----------------------------------------------------------------
        -- SCENARIO 2: reset and try 3 wrong keys -> LOCK
        ----------------------------------------------------------------
        report "--- SCENARIO 2: reset, 3 wrong attempts and LOCK ---" severity note;

        -- Global reset
        tb_rst <= '1';
        wait for 50 ns;
        tb_rst <= '0';
        wait for 50 ns;

        -- Configure key again: 1010
        tb_sw_key   <= "1010";
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';
        wait for 50 ns;

        report "Key 1010 configured again. Entering S_VERIFY..." severity note;

        -- Attempt 1: wrong key 0000
        tb_sw_key <= "0000";
        wait for 50 ns;
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';
        wait for 100 ns;
        report "Attempt 1 (wrong). Attempts left = " &
               integer'image(to_integer(tb_attempts_left)) severity note;

        -- Attempt 2: wrong key 0001
        tb_sw_key <= "0001";
        wait for 50 ns;
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';
        wait for 100 ns;
        report "Attempt 2 (wrong). Attempts left = " &
               integer'image(to_integer(tb_attempts_left)) severity note;

        -- Attempt 3: wrong key 0010
        tb_sw_key <= "0010";
        wait for 50 ns;
        tb_btn_ok_p <= '1';
        wait for TB_CLK_PERIOD;
        tb_btn_ok_p <= '0';
        wait for 100 ns;

        report "Attempt 3 (wrong). It should enter LOCK state now." severity note;

        wait for 200 ns;
        report "LOCK state: lock_active = " &
               std_logic'image(tb_lock_active) &
               "  remaining_sec = " &
               integer'image(to_integer(tb_remaining_sec)) severity note;

        ----------------------------------------------------------------
        -- Wait until LOCK finishes (30 ticks accelerated)
        ----------------------------------------------------------------
        report "Waiting for the end of LOCK (30 accelerated ticks)..." severity note;
        wait for TB_TICK_PERIOD * 40;  -- some margin

        report "After unlock: lock_active = " &
               std_logic'image(tb_lock_active) &
               "  attempts_left = " &
               integer'image(to_integer(tb_attempts_left)) &
               "  state_debug = " &
               integer'image(to_integer(unsigned(tb_state_debug))) severity note;

        report "=== END OF AUTH_BLOCK SIMULATION ===" severity note;
        wait;
    end process;

end sim;

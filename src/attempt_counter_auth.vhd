library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity attempt_counter_auth is
    Port (
        clk           : in  STD_LOGIC;
        rst           : in  STD_LOGIC;
        new_try       : in  STD_LOGIC;               -- pulso: entramos a S_CHECK
        success       : in  STD_LOGIC;               -- acierto (match=1 en S_CHECK)
        reload        : in  STD_LOGIC;               -- recarga externa (p.ej., tras S_LOCK o CONFIG)
        attempts_left : out unsigned(1 downto 0);    -- 0..3
        locked        : out STD_LOGIC                -- '1' si se agotó (informativo)
    );
end attempt_counter_auth;

architecture Behavioral of attempt_counter_auth is
    signal cnt : unsigned(1 downto 0) := "11"; -- 3 intentos
    signal lck : STD_LOGIC := '0';
begin

    process(clk, rst)
        variable next_cnt : unsigned(1 downto 0);
    begin
        if rst = '1' then
            cnt <= "11";     -- 3 intentos
            lck <= '0';
        elsif rising_edge(clk) then
            -- Por defecto, mantener el valor actual
            next_cnt := cnt;

            ------------------------------------------------------------
            -- 1) RECARGA explícita (tiene máxima prioridad)
            --    Se usa cuando auth_block sale de S_LOCK o S_CONFIG.
            ------------------------------------------------------------
            if reload = '1' then
                next_cnt := "11";     -- 3 intentos

            ------------------------------------------------------------
            -- 2) NUEVO INTENTO (new_try='1'): aquí SÍ miramos success
            ------------------------------------------------------------
            elsif new_try = '1' then
                if success = '1' then
                    -- Intento correcto: recargar a 3 intentos
                    next_cnt := "11";
                else
                    -- Intento fallido: descontar si aún hay intentos
                    if cnt > "00" then
                        next_cnt := cnt - 1;
                    end if;
                end if;
            end if;

            -- Actualizar registro
            cnt <= next_cnt;

            -- Señal de bloqueo: se enciende si los intentos llegaron a 0
            if next_cnt = "00" then
                lck <= '1';
            else
                lck <= '0';
            end if;
        end if;
    end process;

    attempts_left <= cnt;
    locked        <= lck;

end Behavioral;

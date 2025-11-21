library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity rnd4_lfsr is
    Port (
        clk    : in  STD_LOGIC;                  -- reloj rápido (CLK100MHZ)
        rst    : in  STD_LOGIC;                  -- reset síncrono/async (según tu estilo)
        enable : in  STD_LOGIC;                  -- cuando es '1' el LFSR avanza
        rnd    : out STD_LOGIC_VECTOR(3 downto 0) -- valor pseudoaleatorio (1..15 aprox)
    );
end rnd4_lfsr;

architecture Behavioral of rnd4_lfsr is
    -- LFSR de 4 bits con taps en bits 4 y 3 (polinomio x^4 + x^3 + 1)
    -- Genera una secuencia de longitud 15 (todas las combinaciones excepto 0000)
    signal r   : STD_LOGIC_VECTOR(3 downto 0) := "1011"; -- semilla no nula
    signal nxt : STD_LOGIC_VECTOR(3 downto 0);
begin
    -- Cálculo del siguiente valor del LFSR
    nxt <= r(2 downto 0) & (r(3) xor r(2));

    process(clk, rst)
    begin
        if rst = '1' then
            -- Semilla fija distinta de 0000
            r <= "1011";
        elsif rising_edge(clk) then
            if enable = '1' then
                -- Evitar caer en 0000: si se da el caso, forzamos 0001
                if nxt = "0000" then
                    r <= "0001";
                else
                    r <= nxt;
                end if;
            end if;
        end if;
    end process;

    rnd <= r;
end Behavioral;

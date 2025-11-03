----------------------------------------------------------------------------------
-- ADC Reader (old continuous-shift logic, updated ports)
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL; 
library UNISIM; 
use UNISIM.VComponents.all;


entity adc_read is
  Port (
    clk_in      : in    std_logic;                       -- input clock
    rst         : in    std_logic;                       -- reset
    sclk        : out   std_logic;                       -- serial clock to ADC
    startConv   : in    std_logic;                       -- was "read_en"
    cs          : out   std_logic;                       -- chip select
    data_ready  : out   std_logic;                       -- data valid flag
    sdata       : in    std_logic;                       -- serial data from ADC
    out_data    : out   std_logic_vector (15 downto 0)   -- parallel output
  );
end adc_read;

architecture Behavioral of adc_read is
    signal adc_reg    : std_logic_vector (15 downto 0);
    signal clk        : std_logic;
    signal ready      : std_logic := '0';
    signal count      : integer := 0;
    signal cs_int     : std_logic := '1';
    signal locked : std_logic;
    
    component clk_wiz_0
        port(
           clk_out1   : out std_logic;
           reset      : in  std_logic;
           locked     : out std_logic;
           clk_in1    : in std_logic
            );
    end component;
    

begin

    
    ClockGen : clk_wiz_0 port map( clk_out1 => clk, reset => rst, locked => locked, clk_in1 => clk_in ); 
    BUFG_02: BUFG port map(I => clk, O => sclk);
        

    cs   <= cs_int;
    data_ready <= ready;


    process (clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                cs_int   <= '1';
                ready    <= '0';
                count    <= 0;
            else
                if (startConv = '1') then
                    if (count < 16) then
                        cs_int   <= '0';
                        ready    <= '0';
                        count    <= count + 1;
                    elsif count = 16 then
                        cs_int   <= '1';
                        count    <= count + 1;
                    elsif count > 16 then
                        ready <= '1';
                        out_data <= adc_reg;
                    else 
                        ready <= '0';
                    end if;
                else
                    cs_int   <= '1';
                    ready    <= '0';
                    count    <= 0;
                 end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Latch output data on falling edge once ready
    --------------------------------------------------------------------
    process (clk)
    begin
        if falling_edge(clk) then
            if (rst = '1') then
                adc_reg  <= (others => '0');
            elsif (cs_int = '0') then
--                out_data <= adc_reg;
                adc_reg  <= adc_reg(14 downto 0) & sdata;
            end if;
        end if;
    end process;

end Behavioral;

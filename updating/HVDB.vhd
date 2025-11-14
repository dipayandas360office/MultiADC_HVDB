library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity HVDB is
  Port ( 
  HVDB_control_in : in std_logic; -- signal when command arrives
  HVDB_control_out : out std_logic; -- signal when the process is complete
  
  HVDB_control_in_write : in std_logic; -- signal when command arrives
  HVDB_control_out_write : out std_logic; -- signal when the process is complete
  
  HVDB_state_data : out std_logic_vector (31 downto 0); ---- data about the state of the HVDB channel
  
  
  command : in std_logic_vector (31 downto 0);
  
  clk : in std_logic;
  reset : in std_logic;
  
  VMON : in std_logic; -- input read from board
  
  
  InputState : out std_logic;
  Chnl_select : out std_logic_vector(3 downto 0);
  Write_MUX_select : out std_logic_vector(1 downto 0);
  Read_MUX_select : out std_logic_vector(1 downto 0)
  );
end HVDB;

architecture Behavioral of HVDB is 
    signal count   , read_count : integer := 0;
    signal VMON_s  : std_logic:='0';
    signal SelectMUX_in         : std_logic_vector (1 downto 0);
    signal SelectChannel_in  , Read_chnl_in   : std_logic_vector (3 downto 0);
    signal channel_index    : integer := 0;
    signal HVDB_state_data_s    : std_logic_vector (23 downto 0);
    signal Read_mux_in : std_logic_vector(1 downto 0);
begin
--    SelectMUX_in <= command(3 downto 0);
--    SelectChannel_in <= command (7 downto 4);

--WRITING : process (clk, HVDB_control_in_write)
--begin
--    if rising_edge(clk) then
--        if reset = '1' then 
--            Chnl_select <= "0000";
--            Write_MUX_select <= "11";
--            InputState <= '0';
--            count <= 0;
--        elsif HVDB_control_in_write = '1' and count < 5 then 
--            count <= count+1;
--            Write_MUX_select <= SelectMUX_in;
--            Chnl_select <= SelectChannel_in;                                
--        elsif HVDB_control_in_write = '1' and count >= 5 and count < 1000005 then
--            count <= count+1;
--            if command(7 downto 0) = x"74" then 
--                InputState <= not VMON_s; 
--            elsif command(7 downto 0) = x"31" then
--                InputState <= '1';
--            elsif command(7 downto 0) = x"30" then
--                InputState <= '0';
--            end if;
--        elsif HVDB_control_in_write = '1' and count >= 1000005 and count < 1000007 then
--            count <= count+1;    
--            HVDB_control_out_write <= '1';            
--        elsif HVDB_control_in_write = '0'  then 
--            count <= 0;  
--            Write_MUX_select <= "11";
--            HVDB_control_out_write <= '0';
--            InputState <= '0'; ------------ modified to make it a pulse  
            
  reading : process (clk , HVDB_control_in) 
  begin    
  if rising_edge(clk) then 
        if HVDB_control_in = '1' and read_count < 24 then
            HVDB_state_data_s <= HVDB_state_data_s(23 downto 1) & VMON ;  
            read_count <= read_count+1;
            Chnl_select <= Read_chnl_in;
            Read_MUX_select <= Read_mux_in;
            HVDB_control_out <= '0';
         elsif  HVDB_control_in = '1' and read_count = 24 then
            read_count <= 0;
            HVDB_state_data <= x"11" & HVDB_state_data_s;
            HVDB_control_out <= '1';
         elsif HVDB_control_in = '0' then
            HVDB_control_out <= '0';
            Read_MUX_select <= "11";
            end if;
        end if;    
    end process;
    
COMMAND_DECODER : process(command)
begin
    case command(31 downto 8) is
        ----------------------------------------------------
        --  a01..a14 → MUX0  → SelectMUX_in = "10"
        ----------------------------------------------------
        when x"613031" =>  -- a01
            SelectChannel_in <= "0001";
            SelectMUX_in     <= "10";
    
        when x"613032" =>  -- a02
            SelectChannel_in <= "0010";
            SelectMUX_in     <= "10";
    
        when x"613033" =>  -- a03
            SelectChannel_in <= "0011";
            SelectMUX_in     <= "10";
    
        when x"613034" =>  -- a04
            SelectChannel_in <= "0100";
            SelectMUX_in     <= "10";
    
        when x"613035" =>  -- a05
            SelectChannel_in <= "0101";
            SelectMUX_in     <= "10";
    
        when x"613036" =>  -- a06
            SelectChannel_in <= "0110";
            SelectMUX_in     <= "10";
    
        when x"613037" =>  -- a07
            SelectChannel_in <= "0111";
            SelectMUX_in     <= "10";
    
        when x"613038" =>  -- a08
            SelectChannel_in <= "1000";
            SelectMUX_in     <= "10";
    
        when x"613039" =>  -- a09
            SelectChannel_in <= "1001";
            SelectMUX_in     <= "10";
    
        when x"613130" =>  -- a10
            SelectChannel_in <= "1010";
            SelectMUX_in     <= "10";
    
        when x"613131" =>  -- a11
            SelectChannel_in <= "1011";
            SelectMUX_in     <= "10";
    
        when x"613132" =>  -- a12
            SelectChannel_in <= "1100";
            SelectMUX_in     <= "10";
    
        when x"613133" =>  -- a13
            SelectChannel_in <= "1101";
            SelectMUX_in     <= "10";
    
        when x"613134" =>  -- a14
            SelectChannel_in <= "1110";
            SelectMUX_in     <= "10";
    
    
        ----------------------------------------------------
        --  a15..a24 → MUX1  → SelectMUX_in = "01"
        ----------------------------------------------------
        when x"613135" =>  -- a15
            SelectChannel_in <= "0001";
            SelectMUX_in     <= "01";
    
        when x"613136" =>  -- a16
            SelectChannel_in <= "0010";
            SelectMUX_in     <= "01";
    
        when x"613137" =>  -- a17
            SelectChannel_in <= "0011";
            SelectMUX_in     <= "01";
    
        when x"613138" =>  -- a18
            SelectChannel_in <= "0100";
            SelectMUX_in     <= "01";
    
        when x"613139" =>  -- a19
            SelectChannel_in <= "0101";
            SelectMUX_in     <= "01";
    
        when x"613230" =>  -- a20
            SelectChannel_in <= "0110";
            SelectMUX_in     <= "01";
    
        when x"613231" =>  -- a21
            SelectChannel_in <= "0111";
            SelectMUX_in     <= "01";
    
        when x"613232" =>  -- a22
            SelectChannel_in <= "1000";
            SelectMUX_in     <= "01";
    
        when x"613233" =>  -- a23
            SelectChannel_in <= "1001";
            SelectMUX_in     <= "01";
    
        when x"613234" =>  -- a24
            SelectChannel_in <= "1010";
            SelectMUX_in     <= "01";
    
    
        ----------------------------------------------------
        --   DEFAULT = DISABLE → SelectMUX_in = "11"
        ----------------------------------------------------
        when others =>
            SelectChannel_in <= "0000";
            SelectMUX_in     <= "11";
    
    end case;

end process;


process(read_count)
begin
    case read_count is

        ----------------------------------------------------
        --  1 .. 14  → MUX0  → SelectMUX_in = "10"
        ----------------------------------------------------
        when 1  => Read_chnl_in <= "0001"; Read_mux_in <= "10";
        when 2  => Read_chnl_in <= "0010"; Read_mux_in <= "10";
        when 3  => Read_chnl_in <= "0011"; Read_mux_in <= "10";
        when 4  => Read_chnl_in <= "0100"; Read_mux_in <= "10";
        when 5  => Read_chnl_in <= "0101"; Read_mux_in <= "10";
        when 6  => Read_chnl_in <= "0110"; Read_mux_in <= "10";
        when 7  => Read_chnl_in <= "0111"; Read_mux_in <= "10";
        when 8  => Read_chnl_in <= "1000"; Read_mux_in <= "10";
        when 9  => Read_chnl_in <= "1001"; Read_mux_in <= "10";
        when 10 => Read_chnl_in <= "1010"; Read_mux_in <= "10";
        when 11 => Read_chnl_in <= "1011"; Read_mux_in <= "10";
        when 12 => Read_chnl_in <= "1100"; Read_mux_in <= "10";
        when 13 => Read_chnl_in <= "1101"; Read_mux_in <= "10";
        when 14 => Read_chnl_in <= "1110"; Read_mux_in <= "10";

        ----------------------------------------------------
        --  15 .. 24 → MUX1  → SelectMUX_in = "01"
        ----------------------------------------------------
        when 15 => Read_chnl_in <= "0001"; Read_mux_in <= "01";
        when 16 => Read_chnl_in <= "0010"; Read_mux_in <= "01";
        when 17 => Read_chnl_in <= "0011"; Read_mux_in <= "01";
        when 18 => Read_chnl_in <= "0100"; Read_mux_in <= "01";
        when 19 => Read_chnl_in <= "0101"; Read_mux_in <= "01";
        when 20 => Read_chnl_in <= "0110"; Read_mux_in <= "01";
        when 21 => Read_chnl_in <= "0111"; Read_mux_in <= "01";
        when 22 => Read_chnl_in <= "1000"; Read_mux_in <= "01";
        when 23 => Read_chnl_in <= "1001"; Read_mux_in <= "01";
        when 24 => Read_chnl_in <= "1010"; Read_mux_in <= "01";

        ----------------------------------------------------
        --   DEFAULT = DISABLE
        ----------------------------------------------------
        when others =>
            Read_chnl_in <= "0000";
            Read_mux_in     <= "11";

    end case;
end process;


end Behavioral;

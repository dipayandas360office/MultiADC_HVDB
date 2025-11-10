library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity HVDB is
  Port ( 
  HVDB_control_in : in std_logic; -- signal when command arrives
  HVDB_control_out : out std_logic; -- signal when the process is complete
  HVDB_state_data : out std_logic_vector (31 downto 0); ---- data about the state of the HVDB channel
  
  
  command : in std_logic_vector (31 downto 0);
  
  clk : in std_logic;
  reset : in std_logic;
  
  VMON : in std_logic; -- input read from board
  
  
  InputState : out std_logic;
  Chnl_select : out std_logic_vector(3 downto 0);
  MUX_select : out std_logic_vector(3 downto 0)
  );
end HVDB;

architecture Behavioral of HVDB is 
    signal count                : integer := 0;
    signal VMON_s               : std_logic:='0';
    signal SelectMUX_in         : std_logic_vector (3 downto 0);
    signal SelectChannel_in     : std_logic_vector (3 downto 0);
    signal channel_index    : integer := 0;
begin
--    SelectMUX_in <= command(3 downto 0);
--    SelectChannel_in <= command (7 downto 4);

    WRITING : process (clk, HVDB_control_in)
    begin
        if rising_edge(clk) then
            if reset = '1' then 
                Chnl_select <= "0000";
                MUX_select <= "1111";
                InputState <= '0';
                count <= 0;
            elsif HVDB_control_in = '1' and count < 5 then 
                count <= count+1;
                MUX_select <= SelectMUX_in;
                Chnl_select <= SelectChannel_in;              
            elsif HVDB_control_in = '1' and count < 15 and count >= 5 then
                VMON_s <= VMON;    
                count <= count+1;                    
            elsif HVDB_control_in = '1' and count >= 15 and count < 10000015 then
                count <= count+1;
                if command(7 downto 0) = x"74" then 
                    InputState <= not VMON_s; 
                elsif command(7 downto 0) = x"31" then
                    InputState <= '1';
                elsif command(7 downto 0) = x"30" then
                    InputState <= '0';
                else  
                    InputState <= '0';
                end if;
            elsif HVDB_control_in = '1' and count >= 10000015 and count < 10000025 then
                VMON_s <= VMON;  
                count <= count+1;                
            elsif HVDB_control_in = '1' and count >= 10000025 and count < 10000035 then
                count <= count+1;                
--                HVDB_state_data <= command(31 downto 8) & "0000000" & VMON; 
                HVDB_state_data <= command; 
                HVDB_control_out <= '1';
                MUX_select <= "1111";
            elsif HVDB_control_in = '0'  then 
                count <= 0;  
                MUX_select <= "1111";
                HVDB_control_out <= '0';
                InputState <= '0'; ------------ modified to make it a pulse
                
--                Chnl_select <= "0000";            
            end if;         
        end if; 
    end process;
    
    
COMMAND_DECODER : process(command)
begin
    case command(31 downto 8) is

        when x"613031" =>  -- "a01"
            SelectChannel_in <= "0001";  -- channel 1
            SelectMUX_in     <= "1010";  -- swapped MUX

        when x"613032" =>  -- "a02"
            SelectChannel_in <= "0010";
            SelectMUX_in     <= "1010";

        when x"613033" =>  -- "a03"
            SelectChannel_in <= "0011";
            SelectMUX_in     <= "1010";

        when x"613034" =>  -- "a04"
            SelectChannel_in <= "0100";
            SelectMUX_in     <= "1010";

        when x"613035" =>  -- "a05"
            SelectChannel_in <= "0101";
            SelectMUX_in     <= "1010";

        when x"613036" =>  -- "a06"
            SelectChannel_in <= "0110";
            SelectMUX_in     <= "1010";

        when x"613037" =>  -- "a07"
            SelectChannel_in <= "0111";
            SelectMUX_in     <= "1010";

        when x"613038" =>  -- "a08"
            SelectChannel_in <= "1000";
            SelectMUX_in     <= "1010";

        when x"613039" =>  -- "a09"
            SelectChannel_in <= "1001";
            SelectMUX_in     <= "1010";

        when x"613130" =>  -- "a10"
            SelectChannel_in <= "1010";
            SelectMUX_in     <= "1010";

        when x"613131" =>  -- "a11"
            SelectChannel_in <= "1011";
            SelectMUX_in     <= "1010";

        when x"613132" =>  -- "a12"
            SelectChannel_in <= "1100";
            SelectMUX_in     <= "1010";

        when x"613133" =>  -- "a13"
            SelectChannel_in <= "1101";
            SelectMUX_in     <= "1010";

        when x"613134" =>  -- "a14"
            SelectChannel_in <= "1110";
            SelectMUX_in     <= "1010";

        -- now channels 15..24 on MUX1 (swapped)
        when x"613135" =>  -- "a15"
            SelectChannel_in <= "0001";
            SelectMUX_in     <= "0101";  -- swapped MUX

        when x"613136" =>  -- "a16"
            SelectChannel_in <= "0010";
            SelectMUX_in     <= "0101";

        when x"613137" =>  -- "a17"
            SelectChannel_in <= "0011";
            SelectMUX_in     <= "0101";

        when x"613138" =>  -- "a18"
            SelectChannel_in <= "0100";
            SelectMUX_in     <= "0101";

        when x"613139" =>  -- "a19"
            SelectChannel_in <= "0101";
            SelectMUX_in     <= "0101";

        when x"613230" =>  -- "a20"
            SelectChannel_in <= "0110";
            SelectMUX_in     <= "0101";

        when x"613231" =>  -- "a21"
            SelectChannel_in <= "0111";
            SelectMUX_in     <= "0101";

        when x"613232" =>  -- "a22"
            SelectChannel_in <= "1000";
            SelectMUX_in     <= "0101";

        when x"613233" =>  -- "a23"
            SelectChannel_in <= "1001";
            SelectMUX_in     <= "0101";

        when x"613234" =>  -- "a24"
            SelectChannel_in <= "1010";
            SelectMUX_in     <= "0101";

        when others =>
            -- invalid → disable mux
            SelectChannel_in <= "0000";
            SelectMUX_in     <= "1111";
    end case;
end process;


end Behavioral;

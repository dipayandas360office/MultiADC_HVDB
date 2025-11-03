library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library UNISIM;
use UNISIM.VComponents.all;

entity top is
    generic (
        baud                : positive := 921600;
        clock_frequency     : positive := 100_000_000
    );
    port (  
        clock                   :   in      std_logic;
        user_reset              :   in      std_logic;  
        control                 :   in      std_logic_vector(3 downto 0); 
        usb_rs232_rxd           :   in      std_logic;
        usb_rs232_txd           :   out     std_logic;
        led2_r                  :   out     std_logic;
        led3_b                  :   out     std_logic;

-------------------ADC1 Ports--------------------------------------------------
        sclk1                    :   out     std_logic;
        cs1                      :   out     std_logic;
        sdata1                   :   in      std_logic;
------------------------------------------------------------------------------     


-------------------ADC2 Ports--------------------------------------------------
        sclk2                    :   out     std_logic;
        cs2                      :   out     std_logic;
        sdata2                   :   in      std_logic;
------------------------------------------------------------------------------

-------------------HVDB ports --------------------------------
        ReadPin                     : in std_logic;
        WritePin                    : out std_logic;
        HVDB_MUX_select             : out std_logic_vector (3 downto 0);
        HVDB_chnl_select            : out std_logic_vector (3 downto 0);

------------------MUX ports----------------------------------------------------

        selectLines             : out std_logic_vector(3 downto 0);  
        selectSignals           : out std_logic_vector(3 downto 0) ;
 -------------------------------------------------------------------------------  
      -- Ethernet MII  DP83848J
        eth_ref_clk             : out std_logic;                    -- Reference Clock X1
        eth_mdc                 : out std_logic;
        eth_mdio                : inout std_logic;
        eth_rstn                : out std_logic;                    -- Reset Phy
        eth_rx_clk              : in  std_logic;                     -- Rx Clock
        eth_rx_dv               : in  std_logic;                     -- Rx Data Valid
        eth_rxd                 : in  std_logic_vector(3 downto 0);  -- RxData
        eth_rxerr               : in  std_logic;                     -- Receive Error
        eth_col                 : in  std_logic;                     -- Ethernet Collision
        eth_crs                 : in  std_logic;                     -- Ethernet Carrier Sense
        eth_tx_clk              : in  std_logic;                     -- Tx Clock
        eth_tx_en               : out std_logic;                     -- Transmit Enable
        eth_txd                 : out std_logic_vector(3 downto 0);  -- Transmit Data
        -- SPI Flash Mem
        qspi_cs                 : out std_logic;        
        qspi_dq                 : inout std_logic_vector(3 downto 0)   -- dg(0) is MOSI, dq(1) MISO       
    );
end top;

architecture rtl of top is
    
    -----Common conrol signals----------------------------------------------------------------------------
    signal command_execute ,checkControl  : std_logic := '0';
    signal command                          : std_logic_vector (7 downto 0);
    signal command_enable ,cmd_1              : std_logic := '0';
    signal  command_HVDB                      : std_logic_vector(31 downto 0) := x"00000000";
    
    
    -----Rx Tx of USB--------------------------------------------------------------------------------------
    signal tx, rx, rx_sync, reset, reset_sync       : std_logic;
    signal fifo_data_in_stb_t , fifo_data_out_stb   : std_logic;
    signal  fifo_data_in_t,fifo_data_out            : std_logic_vector ( 7 downto 0);
    signal fifo_empty, fifo_full_t                  : std_logic;
    signal sendLogic                                : std_logic := '0';
    signal startConv                                : std_logic :='0';
    
    ---ADC1 signals ------------------------------------------------------------------------------------------
    signal data_ready1   , ADCselect                   : std_logic ;
    signal adc_out_data1, ADC_data1                    : std_logic_vector(15 downto 0);
    signal startConv1,readData, newData , readData1 , readData2            : std_logic:= '0';
    signal high                                       : std_logic := '1';
    signal low                                        : std_logic := '0';
    signal timerCount                                 : unsigned(27 downto 0) := x"0000000";
    signal TimeADC                                    : std_logic_vector(31 downto 0);
    signal DataTypeADC                                : std_logic_vector(7 downto 0);
    signal DeviceID_ADC                               : std_logic_vector(7 downto 0);
    signal TransmitDataADC                            : std_logic_vector(15 downto 0);
    
        
    ---ADC2 signals ------------------------------------------------------------------------------------------
    signal data_ready2                                 : std_logic ;
    signal adc_out_data2 , ADC_data2                            : std_logic_vector(15 downto 0);
    signal startConv2             : std_logic:= '0';

    
    ---Transmit control signals -----------------------------------------------------------------------------
    type  Tranmitcontrol is  (ADC_Transmit, Loopback, ADC2_transmit);
    signal DataTranmitActive, ADCreadActive           : std_logic:='0';
    signal DataTime                                   : std_logic_vector(31 downto 0);
    signal DataType                                   : std_logic_vector(7 downto 0);
    signal DeviceID                                   : std_logic_vector(23 downto 0);
    signal TransmitData                               : std_logic_vector(15 downto 0);
    signal byteCount                                  : unsigned(3 downto 0):="0000";
    signal TX_wait_ack ,ack_received                  : std_logic;
    
    ---Timer control signal     -----------------------------------------------------------------------------
    signal TimeCounter                                : unsigned(31 downto 0):= (others=>'0');
    signal TimeCounterTmp                             : std_logic_vector(31 downto 0):= (others=>'0');
    signal ReduceSpeed                                : unsigned(27 downto 0):= (others=>'0');
    signal dataCount                                  : unsigned(15 downto 0):= (others=>'0');
    signal resetTimer  , timeron                      : std_logic := '0';
    
    ---State Declaration-------------------------------------------------------------------------------------
    type adc_state is (START_READ,START_READ1, STOP_READ, IDLE,trasnmit,START_READ_HVDB);
    signal adc_read_state : adc_state := IDLE ;
    
 ------- Control SIgnals and states----------------------------------------------------------------------------
    signal readActive                                 : std_logic := '0';
    signal stateActive                                : unsigned(1 downto 0):="00";
    signal readState                                  : std_logic:='0';
    signal readCount, readCount_eth                   : unsigned(3 downto 0):= "0000";
    signal stateRx1, stateRx2, stateRx3, stateRx4     : std_logic := '0'; 
    signal stateRx1_eth, stateRx2_eth, stateRx3_eth   : std_logic := '0'; 
    signal readDone, readDone_eth                     : std_logic := '0';
    signal rxDataReady, rxDataReady_eth               : std_logic := '0';
    signal sendCount,countTxdata                      : unsigned(3 downto 0) := "0000";
    signal receiveCount, receiveCount_eth             : unsigned(4 downto 0):= "00000";
    signal Txdone, Txdone_eth                         : std_logic := '0';
    type reg_array_type is array (0 to 7) of std_logic_vector(7 downto 0);
    signal Rxdata, Txdata : reg_array_type := (others => (others => '0'));
    type reg_array_type_eth is array (0 to 9) of std_logic_vector(7 downto 0);
    signal Rxdata_eth, Txdata_eth : reg_array_type_eth := (others => (others => '0'));
    
 ---------------80MHz signal-----------------------------------------------------------------------------------
   signal clk_80                                      : std_logic;
   signal clk_160                                     : std_logic;
   signal locked1                                     : std_logic;
   
----------------16 MHz Signal---------------------------------------------------------------------------------
  signal Clk_16                                       : std_logic;
  signal locked2                                      : std_logic;
    
  ---------------------   Ethernet Signals --------------------------------
  signal fifo_full_t_ethernet                             : std_logic;
  signal fifo_data_in_stb_t_ethernet                      : std_logic;
  signal fifo_data_in_t_ethernet                          : std_logic_vector(7 downto 0);
  signal fifo_empty_r_ethernet                             : std_logic;
  signal fifo_data_out_stb_r_ethernet                      : std_logic;
  signal fifo_data_out_r_ethernet                          : std_logic_vector(7 downto 0);
  
  
  signal flag                                              : std_logic;
  signal bytecnt                                           : unsigned(3 downto 0) := "0000";
  
  ----------------------- Mux Signals----------------------------------------
  signal MUX_selection                                     : unsigned(3 downto 0) := "0000";
  signal LineSelectSignals                                 : std_logic_vector(3 downto 0) := "0000";  
  
  -------------------------- HVDB signals ------------------------------------
    
  signal HVDB_control_in_s , was_idle  : std_logic;
  signal HVDB_cmd_on : std_logic_vector (1 downto 0):="00";
  signal HVDB_control_out_s  : std_logic;
  signal VMON_out         : std_logic;
  
  signal InputState_in     : std_logic;
  signal SelectChannel_in : std_logic_vector(3 downto 0);
  signal SelectMUX_in      : std_logic_vector(3 downto 0);

  signal VMON              : std_logic_vector(31 downto 0);
  
  signal InputState       : std_logic;
  signal Chnl_select       : std_logic_vector(3 downto 0);
  signal MUX_select        : std_logic_vector(3 downto 0);
    
-----------------16MHz clk ------------------------------------------------------------------------------------
component clk_wiz_0
port(
   clk_out1   : out std_logic;
   clk_out2   : out std_logic;
   clk_out3   : out std_logic;
   reset      : in  std_logic;
   locked     : out std_logic;
   clk_in1    : in std_logic
    );
end component;

 -------adc component declaration-------------------------------------------------------------------------------
 
    component  adc_read is
        Port (
        clk_in                  : in    std_logic;
        rst                     : in    std_logic;
        sclk                    : out   std_logic;
        startConv               : in    std_logic;
        cs                      : out   std_logic;
        data_ready              : out   std_logic;
        sdata                   : in    std_logic;
        out_data                : out   std_logic_vector (15 downto 0)
        );
      end component;
       
  ------------uart_command component declaration----------------------------------------------------------------    
      
    component UartCommand is
        generic (
            baud                : positive;
            clock_frequency     : positive
        );
        port(  
        clock                   : in   std_logic;
        reset                   : in   std_logic;  
        rx                      : in   std_logic;
        tx                      : out  std_logic;
        fifo_empty              : out  std_logic;
        fifo_full_t             : out  std_logic;
        fifo_data_in_stb_t      : in   std_logic;
        fifo_data_out_stb       : in   std_logic;
        fifo_data_in_t          : in   std_logic_vector(7 downto 0);
        fifo_data_out           : out  std_logic_vector(7 downto 0)
        );
    end component UartCommand;
 
 ---------------------------Ethernet Component Declaration----------------------------
    component ethernet is 
      Port (
         clock                  : in STD_LOGIC;
         Reset                  : in std_logic;
         
         ----FIFO  pins----------------
        fifo_empty              : out   std_logic;
        fifo_full_t             : out  std_logic;
        fifo_data_in_stb_t      : in   std_logic;
        fifo_data_out_stb       : in   std_logic;
        fifo_data_in_t          : in   std_logic_vector(7 downto 0);
        fifo_data_out           : out  std_logic_vector(7 downto 0);

        -- Ethernet MII  DP83848J
        eth_ref_clk             : out std_logic;                    -- Reference Clock X1
        eth_mdc                 : out std_logic;
        eth_mdio                : inout std_logic;
        eth_rstn                : out std_logic;                    -- Reset Phy
        eth_rx_clk              : in  std_logic;                     -- Rx Clock
        eth_rx_dv               : in  std_logic;                     -- Rx Data Valid
        eth_rxd                 : in  std_logic_vector(3 downto 0);  -- RxData
        eth_rxerr               : in  std_logic;                     -- Receive Error
        eth_col                 : in  std_logic;                     -- Ethernet Collision
        eth_crs                 : in  std_logic;                     -- Ethernet Carrier Sense
        eth_tx_clk              : in  std_logic;                     -- Tx Clock
        eth_tx_en               : out std_logic;                     -- Transmit Enable
        eth_txd                 : out std_logic_vector(3 downto 0);  -- Transmit Data
        
        -- SPI Flash Mem
        qspi_cs                 : out std_logic;        
        qspi_dq                 : inout std_logic_vector(3 downto 0)   -- dg(0) is MOSI, dq(1) MISO
         );   
    end component ethernet;
    
        
    component HVDB is
      Port  ( 
      HVDB_control_in : in std_logic;   -- handshake signals
      HVDB_control_out : out std_logic; -- handshake signals 
      
      HVDB_state_data : out std_logic_vector (31 downto 0); --  data
            
      command : in std_logic_vector (31 downto 0);
      
      clk : in std_logic;
      reset : in std_logic;
      
      VMON : in std_logic;    
      InputState : out std_logic;
      Chnl_select : out std_logic_vector(3 downto 0);
      MUX_select : out std_logic_vector(3 downto 0)
      );
      end component HVDB;
      

begin

   
    --------------Ethernet instance -------------------
      Ethernet_Instance : ethernet 
      Port map(
         clock                  => clock,
         Reset                  => Reset,
         ----FIFO  pins----------------
        fifo_empty             => fifo_empty_r_ethernet ,
        fifo_full_t            => fifo_full_t_ethernet,
        fifo_data_in_stb_t     => fifo_data_in_stb_t_ethernet,
        fifo_data_out_stb      =>  fifo_data_out_stb_r_ethernet,   
        fifo_data_in_t         => fifo_data_in_t_ethernet,
        fifo_data_out          => fifo_data_out_r_ethernet, 
        -- Ethernet MII  DP83848J
        eth_ref_clk             => eth_ref_clk,              -- Reference Clock X1
        eth_mdc                 => eth_mdc,
        eth_mdio                => eth_mdio,
        eth_rstn                => eth_rstn,                    -- Reset Phy
        eth_rx_clk              => eth_rx_clk,                    -- Rx Clock
        eth_rx_dv               => eth_rx_dv,                     -- Rx Data Valid
        eth_rxd                 => eth_rxd,  -- RxData
        eth_rxerr               => eth_rxerr,                     -- Receive Error
        eth_col                 => eth_col,                    -- Ethernet Collision
        eth_crs                 => eth_crs,                    -- Ethernet Carrier Sense
        eth_tx_clk              => eth_tx_clk,                     -- Tx Clock
        eth_tx_en               => eth_tx_en,                     -- Transmit Enable
        eth_txd                 => eth_txd,   -- Transmit Data
        -- SPI Flash Mem
        qspi_cs                 => qspi_cs,        
        qspi_dq                 => qspi_dq   -- dg(0) is MOSI, dq(1) MISO
         );   

    ----------------------------------------------------------------------------
    --  USB Uart_Command instantiation
    ----------------------------------------------------------------------------
    UartCommandInstance : UartCommand
    generic map (
        baud                => 921600,
        clock_frequency     => clock_frequency
    )
    port map (  
        clock               => clock,
        reset               => reset,    
        rx                  => rx,
        tx                  => tx,
        fifo_empty          => fifo_empty,
        fifo_full_t         => fifo_full_t,
        fifo_data_in_stb_t  =>   fifo_data_in_stb_t,
        fifo_data_out_stb   =>  fifo_data_out_stb,
        fifo_data_in_t      =>  fifo_data_in_t ,   
        fifo_data_out       =>  fifo_data_out
       
    );
 
   ----------------------------------------------------------------------------
    -- ADC_read  instantiation
   ----------------------------------------------------------------------------   
    ADC_Read_Instance_1 : adc_read
    
    port map(
        clk_in                => clock,
        rst                   => reset,
        sclk                  => sclk1,   
        startConv             => startConv1,
        cs                    => cs1,
        data_ready            => data_ready1, 
        sdata                 => sdata1,
        out_data              => adc_out_data1     
    );
    
   ----------------------------------------------------------------------------
    -- ADC_read  instantiation
   ----------------------------------------------------------------------------   
    ADC_Read_Instance_2 : adc_read
    
    port map(
        clk_in                => clock,
        rst                   => reset,
        sclk                  => sclk2,   
        startConv             => startConv2,
        cs                    => cs2,
        data_ready            => data_ready2, 
        sdata                 => sdata2,
        out_data              => adc_out_data2     
    );
    
    
    U_HVDB : HVDB
    port map (
        HVDB_control_in  => HVDB_control_in_s,
        HVDB_control_out => HVDB_control_out_s,
        HVDB_state_data         => VMON,

--        InputState_in    => InputState_in,
--        SelectChannel_in => SelectChannel_in,
--        SelectMUX_in     => SelectMUX_in,
        command          => command_HVDB,
        
        clk              => clock,
        reset            => reset,
        
        
        VMON             => ReadPin,  -- input from board
        InputState       => WritePin, -- input to board
        Chnl_select      => HVDB_chnl_select,
        MUX_select       => HVDB_MUX_select
    );

       
    --- 16 MHz AND 80mhz clk_out;
    ClockGen : clk_wiz_0
    port map(
    
    clk_out1  =>  Clk_16,
    clk_out2  =>  clk_80,
    clk_out3  =>  clk_160,
    reset     =>  reset,
    locked    =>  locked2,
    clk_in1   =>  clock
    );
----------------------------------------------------Process Declaration---------

    -- Deglitch inputs
    ----------------------------------------------------------------------------
    deglitch : process (clock)
    begin
        if rising_edge(clock) then
            rx_sync         <= usb_rs232_rxd;
            rx              <= rx_sync;
            reset_sync      <= user_reset;
            reset           <= reset_sync;
            usb_rs232_txd   <= tx;
        end if;
    end process;
     
    ----------------------------TimeStamp  Process---------------------------------------------------------------------------------
    
    timestampProcess : process(clock, resetTimer)
    begin
        if rising_edge(clock) then  
            if reset = '1' or resetTimer = '1' then
                ReduceSpeed <= x"0000000";
                TimeCounter <= x"00000000";
            else  
                --if ReduceSpeed = x"5F5E100" then  ---to convert 100MHz to 1 Hz
                if ReduceSpeed = x"989680" then  ---to convert 100MHz to 10 Hz
                    TimeCounter <= TimeCounter + 1;
                    ReduceSpeed <= x"0000000";
                else  
                    ReduceSpeed <= ReduceSpeed + 1;
                end if;
            end if;
            TimeCounterTmp <= std_logic_vector(TimeCounter);
        end if;
    end process;   
 
    startConv1 <= startConv;
    startConv2 <= startConv;

---------------------------ADC process------------------------------------------------  
    adc_process:  process(clock)
    begin
        if rising_edge(clock) then
            if reset = '1' then
                -- Reset
                command_execute    <= '0';
                fifo_data_out_stb  <= '0';
                adc_read_state     <= IDLE;
                startConv          <= '0';
                readData           <= '0';
                high               <= '1';
                low                <= '0';
                ADCselect          <= '1';                  
                timerCount         <= (others => '0');
                timeron            <= '0';
                MUX_selection      <=  "0000";
                HVDB_cmd_on        <= "00";

            else
                -- Default deassert
                fifo_data_out_stb  <= '0';
                if resetTimer = '1' then
                    resetTimer <= '0';
                end if;
                    
    ----------------Free running Timeout Block ---------------------------            
                if timeron = '1' then 
                    if timerCount < x"0fff680" then  --- for making 1 Hz
                        timerCount <= timerCount + 1;
                    elsif timerCount = x"0fff680" then
                        timerCount <= x"0000000";
                        startConv <= '1';
                        newData <= '1';
                       
                    end if; 
                
                    if timerCount = x"000fff" then
                        startConv <= '0';
                        newData <= '0';
                        readData <= '0';

                    end if;
                end if;
 ---------------------- ADC FSM------------------------------------------------
                case adc_read_state is
                
                    when IDLE =>
                        was_idle <='0';                    
                        timeron <= '0';
                        startConv <= '0';
                        readData <='0';
                        sendLogic <= '0';
                        if HVDB_control_in_s = '1' then
                           adc_read_state <= START_READ_HVDB; 
                           was_idle <='1';
                        elsif command_execute = '1' then
                            if command = x"31" then
                                adc_read_state <= START_READ;
                                timeron <= '1';
                            elsif command = x"32" then
                                adc_read_state <= STOP_READ;                      
                            end if;
                        end if;
                    
                     when START_READ => 
                     if  HVDB_control_out_s = '0' then    
                            if MUX_selection < 1 then
                                if data_ready1 = '1' and readData = '0' and newData = '1'then
        --                            ADC_data <= adc_out_data;                         
                                    readData <= '1';
                                    dataCount <= dataCount + 1;  
                                    DataTime <= std_logic_vector(TimeCounter); 
                                    DataType <= "11111000";
                                    DeviceID <= x"110110";
                                    TransmitData <= adc_out_data1; 
                                    ADCselect   <= '0';                       
                                    
                                elsif readData = '1' then                          
                                    readData <= '0';
                                    adc_read_state <= trasnmit;      
--                                    startConv<= '0';
--                                    newData <= '0';                           
                                    TX_wait_ack  <= '1';
                                end if;
                            else 
                                adc_read_state <= START_READ1;
                            end if;               
                        else  
                              adc_read_state <= START_READ_HVDB;
                        end if;
                                              
                        if command_execute = '1' and command = x"32" then
                            adc_read_state <= STOP_READ;
                        end if;
                        
                        
                    when START_READ_HVDB =>
                        if readData = '0' and HVDB_control_out_s = '1' then                        
                            readData <= '1';
                            dataCount <= dataCount + 1;  
                            DataTime <= std_logic_vector(TimeCounter); 
                            DataType <= "11111000";
                            DeviceID <= VMON(31 downto 8);
                            TransmitData <= x"00" & VMON(7 downto 0);  
                            HVDB_control_in_s <= '0';                                                       
                        elsif readData = '1' then                          
                            readData <= '0';

                            adc_read_state <= trasnmit;                              
                            TX_wait_ack  <= '1';
                        end if;
                        
                        if command_execute = '1' and command = x"32" then
                            adc_read_state <= STOP_READ;
                        end if;                        
                        
                    
                    when START_READ1 =>
                      if HVDB_control_out_s ='0' then  
                        if data_ready2 = '1' and readData = '0' and newData = '1' then                     
                            readData <= '1';
                            dataCount <= dataCount + 1;  
                            DataTime <= std_logic_vector(TimeCounter); 
                            DataType <= "11111000";
                            DeviceID <= x"00000" & LineSelectSignals;
                            TransmitData <= adc_out_data2;
                            ADCselect   <= '1';  
                            
                        elsif readData = '1' then                          
                            readData <= '0';
                            startConv<= '0';
                            newData <= '0';                           
                            TX_wait_ack  <= '1';
                            adc_read_state <= trasnmit;
                            Mux_selection <= Mux_selection +1;
                        end if;
                      else 
                          adc_read_state <= START_READ_HVDB;
                      end if;
                      
                        if command_execute = '1' and command = x"32" then
                            adc_read_state <= STOP_READ;
                        end if;

                    when trasnmit =>
                        case byteCount is
                            when "0000" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DataType;
                                fifo_data_in_t_ethernet <= DataType;
                            when "0001" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= std_logic_vector(dataCount(7 downto 0));
                                fifo_data_in_t_ethernet <= std_logic_vector(dataCount(7 downto 0));
                            when "0010" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= TimeADC(23 downto 16);
                                fifo_data_in_t_ethernet <= TimeADC(23 downto 16);
                            when "0011" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DataTime(15 downto 8);
                                fifo_data_in_t_ethernet <= DataTime(15 downto 8);
                            when "0100" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DataTime(7 downto 0);
                                fifo_data_in_t_ethernet <= DataTime(7 downto 0);
                        
                            -- DeviceID split into 3 bytes
                            when "0101" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DeviceID(23 downto 16);   -- MSB
                                fifo_data_in_t_ethernet <= DeviceID(23 downto 16);
                            when "0110" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DeviceID(15 downto 8);    -- Middle byte
                                fifo_data_in_t_ethernet <= DeviceID(15 downto 8);
                            when "0111" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= DeviceID(7 downto 0);     -- LSB
                                fifo_data_in_t_ethernet <= DeviceID(7 downto 0);
                            -- TransmitData split into 2 bytes
                            when "1000" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= TransmitData(15 downto 8);
                                fifo_data_in_t_ethernet <= TransmitData(15 downto 8);
                            when "1001" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= TransmitData(7 downto 0);
                                fifo_data_in_t_ethernet <= TransmitData(7 downto 0);
                            when "1010" =>
                                fifo_data_in_stb_t       <= '1';
                                fifo_data_in_stb_t_ethernet <= '1';
                                byteCount <= byteCount +"0001";
                                fifo_data_in_t <= "00001010";
                                fifo_data_in_t_ethernet <= "00001010";
                        
                            when others =>
                                byteCount <= "0000";
                                fifo_data_in_stb_t <= '0';
                                fifo_data_in_stb_t_ethernet <= '0';
                                if was_idle ='1' then
                                    adc_read_state <= IDLE; 
                                elsif ADCselect = '0' then
                                    adc_read_state <= START_READ1;
                                elsif ADCselect = '1' then 
                                    adc_read_state <= START_READ;
                                end if;
                        end case;

                        
                        when STOP_READ =>
                            was_idle  <= '0';                    
                            timeron   <= '0';
                            startConv <= '0';
                            readData  <= '0';                        
                            high      <= '1';
                            low       <= '0';
                            command_execute <= '0';  -- <<< clear it here
                            adc_read_state  <= IDLE;
                                                
                        when others =>
                            was_idle  <= '0';                    
                            timeron   <= '0';
                            startConv <= '0';
                            readData  <= '0';                        
                            high      <= '1';
                            low       <= '0';
                            command_execute <= '0';  -- <<< clear it here
                            adc_read_state  <= IDLE;
                end case;
                
                       
---------------------------Reading the Command--------------------------------------------------
                if fifo_empty = '0' and sendLogic = '0' then
                    fifo_data_out_stb <= '1';
                
                    -- Simple command (like 0x31 or 0x32)
                    if (fifo_data_out = x"31" or fifo_data_out = x"32") and HVDB_cmd_on = "00" then
                        command_execute <= '1';
                        command <= fifo_data_out;
                        sendLogic <= sendLogic xor '1';  
                    -- First byte of HVDB command (ignored)
                    elsif fifo_data_out = x"61" or fifo_data_out = x"62" then
                        HVDB_cmd_on <= "01";  -- move to next byte
                        sendLogic <= sendLogic xor '1';  
                        command_HVDB(31 downto 24) <= fifo_data_out;
                    -- Second byte of HVDB command (first useful byte)
                    elsif HVDB_cmd_on = "01" then
                        command_HVDB(23 downto 16) <= fifo_data_out;  -- store as high byte
                        HVDB_cmd_on <= "10";                           -- reset FSM
                        sendLogic <= sendLogic xor '1';    
                    -- Third byte of HVDB command (second useful byte)
                    elsif HVDB_cmd_on = "10" then
                        command_HVDB(15 downto 8) <= fifo_data_out;   -- store as low byte            
                        HVDB_cmd_on <= "11";                           -- reset FSM
                        sendLogic <= sendLogic xor '1';               -- signal complete    
                    -- Fourth byte of HVDB command (third useful byte)
                    elsif HVDB_cmd_on = "11" then
                        command_HVDB(7 downto 0) <= fifo_data_out;   -- store as low byte
                        HVDB_control_in_s <= '1';                     -- trigger processing
                        HVDB_cmd_on <= "00";                           -- reset FSM
                        sendLogic <= sendLogic xor '1';               -- signal complete
                    
                
                    else
                        command_execute <= '0';
                        sendLogic <= sendLogic xor '1';
                        if fifo_data_out = x"33" then
                            resetTimer <= '1';
                        end if;
                    end if;
                                        
                 elsif fifo_empty_r_ethernet = '0' and sendLogic = '0'  then
                    fifo_data_out_stb_r_ethernet       <= '1';
                    if fifo_data_out_r_ethernet = x"31" or fifo_data_out_r_ethernet = x"32" then
                        command_execute <= '1';
                        command <= fifo_data_out_r_ethernet;
                    else    
                        command_execute <= '0';
                        sendLogic <= sendLogic xor '1';
                        if fifo_data_out_r_ethernet = x"33" then
                        resetTimer <= '1';
                        end if;
                    end if;
                elsif sendLogic = '1' then
                    sendLogic <= sendLogic xor '1';
                end if;
              end if;
             end if;
    end process;


     
  led3_b <= newData;
  led2_r <= ADCreadActive;
  selectLines <= LineSelectSignals;
  LineSelectSignals <= std_logic_vector(MUX_selection);
  selectSignals <= LineSelectSignals;
   
  
end rtl;
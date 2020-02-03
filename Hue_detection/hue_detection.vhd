library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hue_detection is
	generic (
		-- Users to add parameters here
        constant R_INDEX : integer := 0;
        constant G_INDEX : integer := 1;
        constant B_INDEX : integer := 2;
        
        constant RGB_PIPELINE_DEPTH : integer := 7;
        constant DELTA_PIPELINE_DEPTH : integer := 5;
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S00_AXIS_TDATA_WIDTH	: integer	:= 32;

		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M00_AXIS_TDATA_WIDTH	: integer	:= 32;
		C_M00_AXIS_START_COUNT	: integer	:= 32
	);
	port (
		-- Users to add ports here

		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXIS
		s00_axis_aclk	: in std_logic;
		s00_axis_aresetn	: in std_logic;
		s00_axis_tready	: out std_logic;
		s00_axis_tdata	: in std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);
		s00_axis_tstrb	: in std_logic_vector((C_S00_AXIS_TDATA_WIDTH/8)-1 downto 0);
		s00_axis_tlast	: in std_logic;
		s00_axis_tvalid	: in std_logic;
        s00_axis_tuser  : in std_logic_vector(0 downto 0);
		-- Ports of Axi Master Bus Interface M00_AXIS
		m00_axis_aclk	: in std_logic;
		m00_axis_aresetn	: in std_logic;
		m00_axis_tvalid	: out std_logic;
		m00_axis_tdata	: out std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);
		m00_axis_tstrb	: out std_logic_vector((C_M00_AXIS_TDATA_WIDTH/8)-1 downto 0);
		m00_axis_tlast	: out std_logic;
		m00_axis_tready	: in std_logic;
		m00_axis_tuser  : out std_logic_vector(0 downto 0)
	);
end hue_detection;

architecture arch_imp of hue_detection is

--        signal  axis_tready : std_logic;
	    signal axis_tdata : std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0) ;
--	    signal axis_tstrb : std_logic_vector(C_S00_AXIS_TDATA_WIDTH/8-1 downto 0);
--	    signal  axis_tlast : std_logic;
--	    signal  axis_tvalid : std_logic;
		 
		signal t1_axis_tstrb, t2_axis_tstrb, t3_axis_tstrb, t4_axis_tstrb, t5_axis_tstrb, t6_axis_tstrb, t7_axis_tstrb, t8_axis_tstrb	:  std_logic_vector((C_S00_AXIS_TDATA_WIDTH/8)-1 downto 0);
		signal t1_axis_tlast, t2_axis_tlast, t3_axis_tlast, t4_axis_tlast, t5_axis_tlast, t6_axis_tlast, t7_axis_tlast, t8_axis_tlast	:  std_logic;
		signal t1_axis_tvalid, t2_axis_tvalid, t3_axis_tvalid, t4_axis_tvalid, t5_axis_tvalid, t6_axis_tvalid, t7_axis_tvalid, t8_axis_tvalid	:  std_logic;
        signal t1_axis_tuser, t2_axis_tuser, t3_axis_tuser, t4_axis_tuser, t5_axis_tuser, t6_axis_tuser, t7_axis_tuser, t8_axis_tuser  :  std_logic_vector(0 downto 0);
        signal t1_axis_tready, t2_axis_tready, t3_axis_tready, t4_axis_tready, t5_axis_tready, t6_axis_tready, t7_axis_tready, t8_axis_tready	:  std_logic;
        
        type t_RGBPipeline is array (0 to RGB_PIPELINE_DEPTH-1, 0 to 2) of integer;
        signal RGBPipeline : t_RGBPipeline;
        
        type t_DeltaPipeline is array (0 to DELTA_PIPELINE_DEPTH-1) of integer;
        signal DeltaPipeline : t_DeltaPipeline;
        
--  signal r_int, g_int, b_int : integer;
--  signal r_int_1, g_int_1, b_int_1 : integer;
--  signal r_int_2, g_int_2, b_int_2 : integer;
--  signal r_int_3, g_int_3, b_int_3 : integer;
--  signal r_int_4, g_int_4, b_int_4 : integer;
--  signal r_int_5, g_int_5, b_int_5 : integer;
--  signal r_int_6, g_int_6, b_int_6 : integer;
  signal max_value, min_value, delta : integer;
  signal max_value2, min_value2 , upper_limit, red_ul, red_ll : integer;
  signal max_value_index, min_value_index : integer range 0 to 2;
--  signal delta2, delta3, delta4 : integer; 
  signal h_value : signed(15 downto 0);
  signal h_value2, h_value3, hue : signed(31 downto 0);
  signal min_max_en : std_logic := '0';
  signal max_done : std_logic := '0';
  signal min_done : std_logic := '0';
  signal hue_done, h_done, h_done1, h_done2  : std_logic := '0';
  signal output_done  : std_logic := '0';
  signal max_min_done : std_logic;
  signal delta_done : std_logic;
  signal add, add2 : integer;
begin

max_min_done <= max_done and min_done;

--RGB pixel pipeline
process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    RGBPipeline(0,R_INDEX) <= to_integer(unsigned(s00_axis_tdata(23 downto 16))); --R
    RGBPipeline(0,G_INDEX) <= to_integer(unsigned(s00_axis_tdata(15 downto 8))); --G
    RGBPipeline(0,B_INDEX) <= to_integer(unsigned(s00_axis_tdata(7 downto 0))); --B
    for i in 1 to RGB_PIPELINE_DEPTH-1 loop
        for j in 0 to 2 loop
            RGBPipeline(i,j) <= RGBPipeline(i - 1,j);
        end loop;
    end loop;
end if;
end process;

--Delta pipeline
process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    if(delta_done = '1') then
        for i in 1 to t_DeltaPipeline'length-1 loop
            DeltaPipeline(i) <= DeltaPipeline(i - 1);
        end loop;
    end if;
end if;
end process;

--Get values in reg, stage 1
process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
    if(s00_axis_aresetn = '1') then
--      r_int <= to_integer(unsigned(s00_axis_tdata(23 downto 16)));
--      g_int <= to_integer(unsigned(s00_axis_tdata(15 downto 8)));
--      b_int <= to_integer(unsigned(s00_axis_tdata( 7 downto 0)));
      t1_axis_tstrb <= s00_axis_tstrb;
      t1_axis_tlast <= s00_axis_tlast;
      t1_axis_tvalid <= s00_axis_tvalid;
      t1_axis_tuser <= s00_axis_tuser;
      min_max_en <= '1';
    end if;
 end if;
end process;

--max calcn
process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_1 <= r_int;
--    g_int_1 <= g_int;
--    b_int_1 <= b_int;
      t2_axis_tstrb <= t1_axis_tstrb;
      t2_axis_tlast <= t1_axis_tlast;
      t2_axis_tvalid <= t1_axis_tvalid;
      t2_axis_tuser <= t1_axis_tuser;
    if(min_max_en = '1') then
        max_done <= '1';
        if ((RGBPipeline(0,R_INDEX) > RGBPipeline(0,1)) and (RGBPipeline(0,R_INDEX) > RGBPipeline(0,2))) then
            max_value <= RGBPipeline(0,R_INDEX);
        elsif (RGBPipeline(0,1) > RGBPipeline(0,R_INDEX) and RGBPipeline(0,1) > RGBPipeline(0,2)) then
            max_value <= RGBPipeline(0,1);
        else 
            max_value <= RGBPipeline(0,2);   
        end if;                
    end if;
 end if;
end process;

--min clacn
process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
    if(min_max_en = '1') then
        min_done <= '1';
      if (RGBPipeline(0,R_INDEX) < RGBPipeline(0,1) and RGBPipeline(0,1) < RGBPipeline(0,2)) then
        min_value <= RGBPipeline(0,0); 
      elsif (RGBPipeline(0,1) < RGBPipeline(0,R_INDEX) and RGBPipeline(0,1) < RGBPipeline(0,2)) then
        min_value <= RGBPipeline(0,1);
      else 
        min_value <= RGBPipeline(0,2);   
      end if;
    end if;
 end if;
end process;

process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_2 <= r_int_1;
--    g_int_2 <= g_int_1;
--    b_int_2 <= b_int_1;
      t3_axis_tstrb <= t2_axis_tstrb;
      t3_axis_tlast <= t2_axis_tlast;
      t3_axis_tvalid <= t2_axis_tvalid;
      t3_axis_tuser <= t2_axis_tuser;
--    max_value2 <= max_value;
--    min_value2 <= min_value;
    if(min_done = '1') then    
        if(max_value = RGBPipeline(1,R_INDEX)) then
            max_value_index <= R_INDEX;
        elsif(max_value = RGBPipeline(1,G_INDEX))then
            max_value_index <= G_INDEX;
        end if;
        else
            max_value_index <= B_INDEX;
        end if;
        
       delta_done <= '1'; 
       DeltaPipeline(0) <= max_value - min_value;
    end if;
end process;

--hue calcn
process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_3 <= r_int_2;
--    g_int_3 <= g_int_2;
--    b_int_3 <= b_int_2;
--    delta2 <= delta;
      t4_axis_tstrb <= t3_axis_tstrb;
      t4_axis_tlast <= t3_axis_tlast;
      t4_axis_tvalid <= t3_axis_tvalid;
      t4_axis_tuser <= t3_axis_tuser;
    if(delta_done = '1') then
        h_done <= '1'; 
        if(DeltaPipeline(0) /= 0) then
            case (max_value_index) is
                when 0 =>
                    h_value <= to_signed((RGBPipeline(2,G_INDEX) - RGBPipeline(2,B_INDEX)), 16);
                    add <= 0;
                when 1 =>
                    h_value <= to_signed((RGBPipeline(2,B_INDEX) - RGBPipeline(2,R_INDEX)), 16);
                    add <= 60*DeltaPipeline(0);
                when 2 =>
                    h_value <= to_signed((RGBPipeline(2,R_INDEX) - RGBPipeline(2,G_INDEX)), 16);
                    add <= 120*DeltaPipeline(0);  
            end case;
        else 
            h_value <= to_signed(0, 16); 
            add <= 0;   
        end if; 
    end if;
 end if;
end process;

process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_4 <= r_int_3;
--    g_int_4 <= g_int_3;
--    b_int_4 <= b_int_3;
--    delta3 <= delta2;
    t5_axis_tstrb <= t4_axis_tstrb;
    t5_axis_tlast <= t4_axis_tlast;
    t5_axis_tvalid <= t4_axis_tvalid;
    t5_axis_tuser <= t4_axis_tuser;
    if(h_done = '1') then
        h_done1 <= '1';
        h_value2 <= 30*h_value;
        add2 <= add;
    end if;
 end if;
end process;


process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_5 <= r_int_4;
--    g_int_5 <= g_int_4;
--    b_int_5 <= b_int_4;
--    delta4 <= delta3;
    upper_limit <= 180*DeltaPipeline(3);
    t6_axis_tstrb <= t5_axis_tstrb;
    t6_axis_tlast <= t5_axis_tlast;
    t6_axis_tvalid <= t5_axis_tvalid;
    t6_axis_tuser <= t5_axis_tuser;
    if(h_done1 = '1') then
        h_done2 <= '1';
        h_value3 <= h_value2 + to_signed(add2,32);
    end if;
 end if;
end process;

process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
--    r_int_6 <= r_int_5;
--    g_int_6 <= g_int_5;
--    b_int_6 <= b_int_5;
    red_ul <= 170*DeltaPipeline(3);
    red_ll <= 10*DeltaPipeline(3);
      t7_axis_tstrb <= t6_axis_tstrb;
      t7_axis_tlast <= t6_axis_tlast;
      t7_axis_tvalid <= t6_axis_tvalid;
      t7_axis_tuser <= t6_axis_tuser;
    if(h_done2 = '1') then
        hue_done <= '1';        
        if(h_value3 < 0) then
            hue <= h_value3 + to_signed(upper_limit,32);
        else 
            hue <= h_value3;
        end if;
    end if;
 end if;
end process;

--output
process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
      t8_axis_tstrb <= t7_axis_tstrb;
      t8_axis_tlast <= t7_axis_tlast;
      t8_axis_tvalid <= t7_axis_tvalid;
      t8_axis_tuser <= t7_axis_tuser;
      if(hue_done = '1') then
        if(hue > red_ul or hue < red_ll) then -- Red threshold
			axis_tdata(23 downto 16) <= std_logic_vector(to_unsigned(RGBPipeline(6,R_INDEX), 8));
			axis_tdata(15 downto 8) <= std_logic_vector(to_unsigned(RGBPipeline(6,G_INDEX), 8));
			axis_tdata(7 downto 0) <= std_logic_vector(to_unsigned(RGBPipeline(6,B_INDEX), 8));
			output_done <= '1';			
		else
			axis_tdata <= (others => '0');
			output_done <= '1';
		end if;
    end if;
 end if;
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then
    if (m00_axis_aresetn = '1') then
        if (output_done = '1') then
            m00_axis_tdata <= axis_tdata;
            m00_axis_tstrb <= t8_axis_tstrb;
            m00_axis_tlast <= t8_axis_tlast;
            m00_axis_tvalid <= t8_axis_tvalid;
            m00_axis_tuser <= t8_axis_tuser;          
        end if; 
     end if;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t1_axis_tready <= m00_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t2_axis_tready <= t1_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t3_axis_tready <= t2_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t4_axis_tready <= t3_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t5_axis_tready <= t4_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t6_axis_tready <= t5_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t7_axis_tready <= t6_axis_tready;
end if;      
end process;

process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then      
        t8_axis_tready <= t7_axis_tready;
end if;      
end process;

process(s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then      
        s00_axis_tready <= t8_axis_tready;
end if;      
end process;

end arch_imp;

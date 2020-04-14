-- Name			: Shoukath Ali Mohammad
-- Title		: bgr2GRAY
-- Description 	: Convert 8 bit rgb pixels to 8bit gray data. Pipeline all the axis signals to next stage

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity convert is
	generic (
			data_width		: integer := 32
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
			
			rgb_tready 		: out std_logic;
			rgb_tvalid 		: in  std_logic;
			rgb_tlast 		: in  std_logic;
			rgb_tdata 		: in  std_logic_vector(data_width-1 downto 0);
			rgb_tkeep       : in  std_logic_vector(data_width/8 -1 downto 0);
			
			gray_tvalid		: out std_logic;
			gray_tlast 		: out std_logic;
			gray_tdata 		: out std_logic_vector(data_width -1 downto 0);
			gray_tready     : in std_logic;
			gray_tkeep      : out  std_logic_vector(data_width/8 -1 downto 0);

			en_stage2 		: out std_logic
	);
end entity convert;

architecture rtl of convert is

	signal tvalid1, tvalid2, tvalid3	: std_logic;
	signal tlast1, tlast2, tlast3 		: std_logic;
    
	signal r_data, g_data, b_data 		: integer range 0 to 38250 ;
	signal gray_data 		            : unsigned(data_width -1 downto 0);     
    signal gray_value                   : unsigned(data_width/4 -1 downto 0);

begin

-- gray = (r*76 + g*150 + b*29 + 128) >> 8

	stage1:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
		if aresetn_in = '0' then
			r_data 		<= 0;
			g_data 		<= 0;
			b_data 		<= 0;
			tvalid1 	<= '0';
			tlast1  	<= '0';
		elsif gray_tready = '1' then		
			r_data 		<= to_integer(unsigned(rgb_tdata(23 downto 16)))*76; --R
			g_data 		<= to_integer(unsigned(rgb_tdata(15 downto 8)))*150; --G
			b_data 		<= to_integer(unsigned(rgb_tdata(7 downto 0)))*29; --B
			tvalid1 	<= rgb_tvalid;
			tlast1  	<= rgb_tlast;
		end if;
		
	end if;
	end process;

	stage2:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
	   if aresetn_in = '0' then
			gray_data   <= (others => '0');
			tvalid2 	<= '0';
			tlast2	 	<= '0';
		elsif gray_tready = '1' then	 
            gray_data 	<= to_unsigned((r_data + g_data + b_data + 128),rgb_tdata'length);
            tvalid2 	<= tvalid1;
            tlast2  	<= tlast1;
       end if;
	end if;
	end process;

	
	stage3:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
		if aresetn_in = '0' then
			gray_value	<= (others => '0');
			tvalid3 	<= '0';
			tlast3  	<= '0';
	   elsif gray_tready = '1' then	
			gray_value 	<= gray_data(15 downto 8);
			tvalid3     <= tvalid2;
			tlast3      <= tlast2;
	   end if;
	end if;
	end process;


	rgb_tready     <= gray_tready;
				   

	gray_tvalid    <= tvalid3;
	gray_tlast 	   <= tlast3;
	gray_tkeep     <= (others => '1');
	                   
	gray_tdata(7 downto 0)		<= std_logic_vector(gray_value);
	gray_tdata(15 downto 8)		<= std_logic_vector(gray_value);
	gray_tdata(23 downto 16)	<= std_logic_vector(gray_value);
	gray_tdata(31 downto 24)	<= (others => '0');

	                                                      	                   
end architecture rtl;
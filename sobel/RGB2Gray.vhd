-- Name			: Shoukath Ali Mohammad
-- Title		: RGB2GRAY
-- Description 	: Convert 8 bit RGB pixels to 8bit gray data. Pipeline all the axis signals to next stage

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity RGB2GRAY is
	generic (
			data_width		: integer
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
			
			rgb_tready 		: out std_logic;
			rgb_tvalid 		: in  std_logic;
			rgb_tlast 		: in  std_logic;
			rgb_tuser 		: in  std_logic_vector(0 downto 0);
			rgb_tdata 		: in  std_logic_vector(data_width-1 downto 0);
			
			gray_tvalid		: out std_logic;
			gray_tlast 		: out std_logic;
			gray_tuser 		: out std_logic_vector(0 downto 0);
			gray_tdata 		: out std_logic_vector(data_width/3-1 downto 0);
			
			initiate_axis 	: in  std_logic;
			en_conv 		: out std_logic
	);
end entity RGB2GRAY;

architecture convert of RGB2GRAY is

	signal tvalid1, tvalid2, tvalid3	: std_logic;
	signal tlast1, tlast2, tlast3 		: std_logic;
	signal tuser1, tuser2, tuser3 		: std_logic_vector(0 downto 0);

	signal r_data, g_data, b_data 		: integer ;
	signal gray_data, gray_value 		: unsigned(data_width -1 downto 0);     

	signal en_stage2, en_stage3, en_next: std_logic;

begin

-- gray = (r * 76 + g * 150 + b * 29 + 128) >> 8

	stage1:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
		if aresetn_in = '1' then
			r_data 		<= to_integer(unsigned(rgb_tdata(23 downto 16)))*76; --R
			g_data 		<= to_integer(unsigned(rgb_tdata))*150; --G
			b_data 		<= to_integer(unsigned(rgb_tdata))*29; --B
			
			tvalid1 	<= rgb_tvalid;
			tlast1  	<= rgb_tlast;
			tuser1  	<= rgb_tuser;
			
			en_stage2 	<= '1';
		else		
			r_data 		<= 0;
			g_data 		<= 0;
			b_data 		<= 0;
			
			tvalid1 	<= '0';
			tlast1  	<= '0';
			tuser1  	<= (others => '0');		

			en_stage2 	<= '0';    
		end if;
		
	end if;
	end process;

	stage2:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
		if(en_stage2 = '1') then   
			gray_data 	<= to_unsigned((r_data + g_data + b_data),rgb_tdata'length);
			
			tvalid2 	<= tvalid1;
			tlast2  	<= tlast1;
			tuser2  	<= tuser1;
			
			en_stage3 	<= '1';
	   else
			gray_data   <= (others => '0');
			
			tvalid2 	<= '0';
			tlast2	 	<= '0';
			tuser2  	<= (others => '0');	
			
			en_stage3 	<= '0';
		end if;
	end if;
	end process;

	stage3:process(aclk_in)
	begin
	if(rising_edge(aclk_in)) then
		if(en_stage3 = '1') then
			gray_value 	<= shift_right(gray_data,gray_tdata'length);

			tvalid3 	<= tvalid2;
			tlast3  	<= tlast2;
			tuser3  	<= tuser2;  
			
			en_next 	<= '1';
		else  
			gray_value	<= (others => '0');
			
			tvalid3 	<= '0';
			tlast3  	<= '0';
			tuser3  	<= (others => '0');	
		
			en_next 	<= '0';	
		end if;
	end if;
	end process;


	rgb_tready		<= 	'1' when aresetn_in = '1' and rgb_tlast = '0' and initiate_axis = '1' else
						'0' when aresetn_in = '1' and rgb_tlast = '1' and initiate_axis = '1' else 
						'0';
				   

	gray_tvalid		<= tvalid3;
	gray_tlast 		<= tlast3;
	gray_tuser 		<= tuser3;
	gray_tdata 		<= std_logic_vector(gray_value(7 downto 0));
				
	en_conv 		<= en_next;

end architecture convert;
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity video_stream_v1_0 is
	generic (
		-- Users to add parameters here
		-- User parameters ends
		-- Do not modify the parameters beyond this line
        image_width 	: integer := 9; -- no. of columns
        image_height 	: integer := 9; -- no. of rows

		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S00_AXIS_TDATA_WIDTH	: integer	:= 24;

		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M00_AXIS_TDATA_WIDTH	: integer	:= 24
	);
	port (
		-- Users to add ports here

		-- User ports ends
		-- Do not modify the ports beyond this line


		-- Ports of Axi Slave Bus Interface S00_AXIS
		s00_axis_aclk		: in  std_logic;
		s00_axis_aresetn	: in  std_logic;
		s00_axis_tready		: out std_logic;
		s00_axis_tdata		: in  std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);
		s00_axis_tlast		: in  std_logic;
		s00_axis_tvalid		: in  std_logic;
        s00_axis_tuser  	: in  std_logic_vector(0 downto 0);
        s00_axis_tkeep  	: in  std_logic_vector(C_S00_AXIS_TDATA_WIDTH/8 -1 downto 0);
		-- Ports of Axi Master Bus Interface M00_AXIS
		m00_axis_aclk		: in  std_logic;
		m00_axis_aresetn	: in  std_logic;
		m00_axis_tvalid		: out std_logic;
		m00_axis_tdata		: out std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);
		m00_axis_tlast		: out std_logic;
		m00_axis_tready		: in  std_logic;
		m00_axis_tuser  	: out std_logic_vector(0 downto 0);
		m00_axis_tkeep  	: out  std_logic_vector(C_M00_AXIS_TDATA_WIDTH/8 -1 downto 0)
	);
end video_stream_v1_0;

architecture arch_imp of video_stream_v1_0 is


	component RGB2GRAY is
		generic (
			data_width 		: integer := 24 ;
			image_width     : integer := 1920
			);
		port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
				
			rgb_tready 		: out std_logic;
			rgb_tvalid 		: in  std_logic;
			rgb_tlast 		: in  std_logic;
--			rgb_tuser 		: in  std_logic_vector(s00_axis_tuser'length -1 downto 0);
			rgb_tdata 		: in  std_logic_vector(data_width-1 downto 0);
			rgb_tkeep       : in  std_logic_vector(data_width/8 -1 downto 0);
			
			gray_tvalid 	: out std_logic;
			gray_tlast 		: out std_logic;
--			gray_tuser 		: out std_logic_vector(s00_axis_tuser'length -1 downto 0);
			gray_tdata 		: out std_logic_vector(data_width/4-1 downto 0);
			gray_tready     : in std_logic;	
            gray_tkeep      : out  std_logic_vector(data_width/8 -1 downto 0);
			en_conv 		: out std_logic
			);
	end component RGB2GRAY;

	component intensity_gradient is
		generic (
			data_width 		: integer := 24;
			image_width 	: integer := 1920;
			image_height	: integer := 1080
			);
		port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
				
			en_conv			: in  std_logic;			
				
			gray_tvalid 	: in  std_logic;
			gray_tlast 		: in  std_logic;
--			gray_tuser 		: in  std_logic_vector(s00_axis_tuser'length -1 downto 0);
			gray_tdata 		: in  std_logic_vector(data_width/4-1 downto 0);
            gray_tready     : out std_logic;
            gray_tkeep      : in  std_logic_vector(data_width/8 -1 downto 0);
            
			aclk_out		: in  std_logic;
			aresetn_out		: in  std_logic;
				
			conv_tready 	: in  std_logic;
			conv_tvalid 	: out std_logic;
			conv_tlast 		: out std_logic;
--			conv_tuser 		: out std_logic_vector(s00_axis_tuser'length -1 downto 0);
			conv_tkeep      : out  std_logic_vector(data_width/8 -1 downto 0);
			conv_tdata 		: out std_logic_vector(data_width-1 downto 0)
			);
	end component intensity_gradient;


	signal tvalid, g_tvalid	: std_logic;
	signal tlast, g_tlast  	: std_logic;
--	signal tuser, g_tuser  	: std_logic_vector(s00_axis_tuser'length -1 downto 0);
	signal g_tdata      	: std_logic_vector(C_S00_AXIS_TDATA_WIDTH/4 -1 downto 0);
	signal en             	: std_logic;
    signal tready, g_tready : std_logic;
    signal tdata            : std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);
    signal tkeep, g_tkeep   : std_logic_vector(C_M00_AXIS_TDATA_WIDTH/8 -1 downto 0);
    
begin

	stage1: RGB2GRAY 
		generic map (
			data_width 		=> C_S00_AXIS_TDATA_WIDTH,
			image_width     => image_width
			)
		port map (	
			aclk_in 		=> s00_axis_aclk,
			aresetn_in 		=> s00_axis_aresetn,
			
			rgb_tready 		=> s00_axis_tready,
			rgb_tvalid 		=> s00_axis_tvalid,
			rgb_tlast 		=> s00_axis_tlast,
--			rgb_tuser 		=> s00_axis_tuser,
			rgb_tdata 		=> s00_axis_tdata,
		    rgb_tkeep       => s00_axis_tkeep,
			
			gray_tvalid 	=> g_tvalid,
			gray_tlast 		=> g_tlast,
--			gray_tuser 		=> g_tuser,
			gray_tdata 		=> g_tdata,
			gray_tready     => g_tready,	
		    gray_tkeep      => g_tkeep,
			en_conv 		=> en 
			);


	stage2: intensity_gradient
		generic map (
			data_width 		=> C_M00_AXIS_TDATA_WIDTH,
			image_width 	=> image_width,
			image_height	=> image_height
			)
		port map(	
			aclk_in 		=> s00_axis_aclk,
			aresetn_in 		=> s00_axis_aresetn,
				
			en_conv			=> en,		
			
			gray_tvalid 	=> g_tvalid,
			gray_tlast 		=> g_tlast,
--			gray_tuser 		=> g_tuser,
			gray_tdata 		=> g_tdata,
            gray_tready     => g_tready,
            gray_tkeep      => g_tkeep,
			aclk_out		=> m00_axis_aclk,
			aresetn_out		=> m00_axis_aresetn,
				
			conv_tready 	=> tready,
			conv_tvalid 	=> tvalid,
			conv_tlast 		=> tlast,
--			conv_tuser 		=> tuser,
			conv_tkeep      => tkeep,
			conv_tdata 		=> tdata	
			);
process(m00_axis_aclk)
begin
if rising_edge(m00_axis_aclk) then
    if m00_axis_aresetn = '1' then
        m00_axis_tvalid 	<= g_tvalid;
        m00_axis_tlast  	<= g_tlast;
--        m00_axis_tuser  	<= g_tuser;
        m00_axis_tkeep      <= tkeep;
        m00_axis_tdata      <= tdata;
--        m00_axis_tdata(23 downto 16)  	<= tdata;
--        m00_axis_tdata(15 downto  8)  	<= tdata;
--        m00_axis_tdata( 7 downto  0)  	<= tdata;
--        m00_axis_tdata(31 downto 24)    <= (others => '0');
    end if;
 end if;	
end process;	
	g_tready          	<= m00_axis_tready;
	

end arch_imp;


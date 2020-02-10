library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity rgb2gray is
	generic (
		-- Users to add parameters here
        constant pipeline_length_aprox : integer := 16;
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S00_AXIS_TDATA_WIDTH	: integer	:= 24;

		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M00_AXIS_TDATA_WIDTH	: integer	:= 24;
		C_M00_AXIS_START_COUNT	: integer	:= 24
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
		s00_axis_tlast	: in std_logic;
		s00_axis_tvalid	: in std_logic;
        s00_axis_tuser  : in std_logic_vector(0 downto 0);
		-- Ports of Axi Master Bus Interface M00_AXIS
		m00_axis_aclk	: in std_logic;
		m00_axis_aresetn	: in std_logic;
		m00_axis_tvalid	: out std_logic;
		m00_axis_tdata	: out std_logic_vector(C_M00_AXIS_TDATA_WIDTH-1 downto 0);
		m00_axis_tlast	: out std_logic;
		m00_axis_tready	: in std_logic;
		m00_axis_tuser  : out std_logic_vector(0 downto 0)
	);
end rgb2gray;

architecture arch_imp of rgb2gray is

-- FIFO to stor STD_LOGIC_VECTOR
component STD_FIFO is
	Generic (
		DATA_WIDTH  : integer := C_M00_AXIS_TDATA_WIDTH;
		FIFO_DEPTH	: integer := pipeline_length_aprox
	);
	Port ( 
		CLK		: in  STD_LOGIC;
		RST		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
		ReadEn	: in  STD_LOGIC;
		DataOut	: out STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0)
	);
end component STD_FIFO;

-- FIFO to store std_logic
component STD_FIFO_SGNL is
	Generic (
		constant DATA_WIDTH  : integer := 1;
		constant FIFO_DEPTH	: integer := pipeline_length_aprox
	);
	Port ( 
		CLK		: in  STD_LOGIC;
		RST		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC;
		ReadEn	: in  STD_LOGIC;
		DataOut	: out STD_LOGIC
	);
end component STD_FIFO_SGNL;

signal s_axis_tlast: std_logic;
signal s_axis_tvalid, axis_tready: std_logic;
signal s_axis_tuser: std_logic_vector(0 downto 0);

signal m_axis_tdata: std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);

signal r_data, g_data, b_data : integer ;
signal gray_data, gray_value : unsigned(C_S00_AXIS_TDATA_WIDTH-1 downto 0);
signal read_FIFO : std_logic;
signal data_stage1, data_stage2, data_stage3, data_stage4 : std_logic;       


begin

tvalid: STD_FIFO_SGNL
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> pipeline_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tvalid,
		ReadEn	=> read_FIFO,
		DataOut	=> s_axis_tvalid
);

tlast: STD_FIFO_SGNL
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> pipeline_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tlast,
		ReadEn	=> read_FIFO,
		DataOut	=> s_axis_tlast
);

tuser: STD_FIFO
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> pipeline_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tuser,
		ReadEn	=> read_FIFO,
		DataOut	=> s_axis_tuser
);

process(s00_axis_aclk)
begin
if (rising_edge(s00_axis_aclk)) then
    if (s00_axis_tvalid = '1' and s00_axis_tlast = '0') then
        axis_tready <= '1';
    elsif (s00_axis_tvalid = '1' and s00_axis_tlast = '1') then
        axis_tready <= '0';
    else 
        axis_tready <= '0';
    end if;
end if;
end process;

--axi_master        axi_slave                           axi_master          axi_slave   
------------|       |----------------------------------------------|       |-----------
--  tvalid--|--->---|--tvalid--->---|STD_FIFO_SGNL  |--->--tvalid--|--->---|--tvalid---    
--  tdata---|--->---|--tdata---->---|data_pipeline  |--->--tdata---|--->---|--tdata----
--  tlast---|--->---|--tlast---->---|STD_FIFO_SGNL  |--->--tlast---|--->---|--tlast----
--          |       |                                              |       |           
--  tready--|---<---|--tready---<-----------------------<--tready--|---<---|--tready---
--          |       |                                              |       |           
--  tuser---|--->---|--tuser---->---|STD_FIFO       |--->--tuser---|--->---|--tuser----
------------|       |-----------------------------------   --------|       |-----------


-- gray = (r * 76 + g * 150 + b * 29 + 128) >> 8
--RGB pixel pipeline
pipeline1:process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    if(s00_axis_tvalid = '1') then
        r_data <= to_integer(unsigned(s00_axis_tdata(23 downto 16)))*76; --R
        g_data <= to_integer(unsigned(s00_axis_tdata(15 downto 8)))*150; --G
        b_data <= to_integer(unsigned(s00_axis_tdata(7 downto 0)))*29; --B
        data_stage1 <= '1';
    else
        data_stage1 <= '0';
    end if;
    
end if;
end process;

pipeline2:process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    if(data_stage1 = '1') then   
        gray_data <= to_unsigned((r_data + g_data + b_data),24);
        data_stage2 <= '1';
    else
        data_stage2 <= '0';
    end if;
end if;
end process;

pipeline3:process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    if(data_stage2 = '1') then
        gray_value <= shift_right(gray_data,8);
        data_stage3 <= '1';
        read_FIFO <= '1';
    else 
        data_stage3 <= '0';
        read_FIFO <= '0';
    end if;
end if;
end process;

pipeline4:process(s00_axis_aclk) is
begin
if(rising_edge(s00_axis_aclk)) then
    if(data_stage3 = '1') then
        m_axis_tdata <= std_logic_vector(gray_value);
        data_stage4 <= '1';
    else 
        data_stage4 <= '0';      
    end if;
end if;
end process;


outputstage:process(m00_axis_aclk) is
begin
if (rising_edge(m00_axis_aclk)) then
    if (m00_axis_aresetn = '1') and (data_stage4  = '1')then
            m00_axis_tdata(23 downto 16) <= m_axis_tdata(7 downto 0);
            m00_axis_tdata(15 downto 8) <= m_axis_tdata(7 downto 0);
            m00_axis_tdata(7 downto 0) <= m_axis_tdata(7 downto 0);

            m00_axis_tlast <= s_axis_tlast;
            m00_axis_tvalid <= s_axis_tvalid;
            m00_axis_tuser <= s_axis_tuser;          
    else
            m00_axis_tdata <= (others => '0');
            m00_axis_tlast <= '0';
            m00_axis_tvalid <= '0';
            m00_axis_tuser <= (others => '0');             
     end if;
end if;      
end process;

s00_axis_tready <= axis_tready;

end arch_imp;

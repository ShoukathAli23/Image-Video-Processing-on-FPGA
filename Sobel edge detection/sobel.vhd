library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity sobel is
	generic (
		-- Users to add parameters here
		-- User parameters ends
		-- Do not modify the parameters beyond this line
        constant image_width : integer := 9; -- no. of columns
        constant image_height : integer := 9; -- no. of rows

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
end sobel;

architecture arch_imp of sobel is
constant FIFO_length_aprox : integer := image_width + 80;

component STD_FIFO is
	Generic (
		DATA_WIDTH  : integer := C_M00_AXIS_TDATA_WIDTH;
		FIFO_DEPTH	: integer := FIFO_length_aprox
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

component STD_FIFO_SGNL is
	Generic (
		constant DATA_WIDTH  : integer := 1;
		constant FIFO_DEPTH	: integer := FIFO_length_aprox
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
signal s_axis_tvalid: std_logic;
signal s_axis_tuser: std_logic_vector(0 downto 0);
signal axis_tready : std_logic;

signal m_axis_tdata: std_logic_vector(C_S00_AXIS_TDATA_WIDTH-1 downto 0);

signal r_data, g_data, b_data : integer ;
signal gray_data, gray_value : unsigned(C_S00_AXIS_TDATA_WIDTH-1 downto 0);     

------- Pipeline signals -----------------------------------------
signal read_FIFO : std_logic;
signal data_stage1, data_stage2, data_stage3, data_stage4, data_stage5, data_stage6, data_stage7 : std_logic;       
------- Pipeline signals -----------------------------------------

------- Convolution signals --------------------------------------
signal counter : integer := 0;
signal sumx, sumy, data  : integer := 0;
signal sum : integer := 0;

signal x1,x2,x3,x4,x5,x6,x7,x8,x9 : integer := 0;
signal y1,y2,y3,y4,y5,y6,y7,y8,y9 : integer := 0;

type line_buffer1 is array (0 to image_width -1) of integer;
type line_buffer2 is array (0 to 2) of integer;
signal inMat1,inMat2 : line_buffer1;
signal inMat3 : line_buffer2 ;

------- Filter ----------------------------------------------------
------- Sobel Gy
constant k1 : integer := -1;
constant k2 : integer := -2;
constant k3 : integer := -1;
constant k4 : integer :=  0;
constant k5 : integer :=  0;
constant k6 : integer :=  0;
constant k7 : integer :=  1;
constant k8 : integer :=  2;
constant k9 : integer :=  1;

------- Sobel Gx
constant m1 : integer :=  1;
constant m2 : integer :=  0;
constant m3 : integer := -1;
constant m4 : integer :=  2;
constant m5 : integer :=  0;
constant m6 : integer := -2;
constant m7 : integer :=  1;
constant m8 : integer :=  0;
constant m9 : integer := -1;
------- Filter ----------------------------------------------------

constant stop_length : integer := image_width + 5;
signal stop_cnt : integer;
signal start : std_logic;

signal fifo_rd, fifo_wr : std_logic;
begin

tvalid: STD_FIFO_SGNL
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> FIFO_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tvalid,
		ReadEn	=> fifo_rd,
		DataOut	=> s_axis_tvalid
);

tlast: STD_FIFO_SGNL
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> FIFO_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tlast,
		ReadEn	=> fifo_rd,
		DataOut	=> s_axis_tlast
);

tuser: STD_FIFO
generic map (
		DATA_WIDTH => 1,
		FIFO_DEPTH	=> FIFO_length_aprox
)
port map (
		CLK		=> s00_axis_aclk,
		RST		=> s00_axis_aresetn,
		WriteEn	=> s00_axis_tvalid,
		DataIn	=> s00_axis_tuser,
		ReadEn	=> fifo_rd,
		DataOut	=> s_axis_tuser
);

--axi_master        axi_slave                           axi_master          axi_slave   
------------|       |----------------------------------------------|       |-----------
--  tvalid--|--->---|--tvalid--->---|STD_FIFO_SGNL  |--->--tvalid--|--->---|--tvalid---    
--  tdata---|--->---|--tdata---->---|data_pipeline  |--->--tdata---|--->---|--tdata----
--  tlast---|--->---|--tlast---->---|STD_FIFO_SGNL  |--->--tlast---|--->---|--tlast----
--          |       |                                              |       |           
--  tready--|---<---|--tready-<-|clocked process|          tready--|---<---|--tready---
--          |       |                                              |       |           
--  tuser---|--->---|--tuser---->---|STD_FIFO       |--->--tuser---|--->---|--tuser----
------------|       |-----------------------------------   --------|       |-----------


-- gray = (r * 76 + g * 150 + b * 29 + 128) >> 8

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

--RGB pixel pipeline
process(s00_axis_aclk)
begin
if(rising_edge(s00_axis_aclk)) then
    if(s00_axis_tvalid = '1' and axis_tready = '1') then
        start <= '1';
    elsif stop_cnt > stop_length then
        start <= '0';
    end if;
end if;
end process;

process(s00_axis_aclk)
begin
if(rising_edge(s00_axis_aclk)) then
    if(s00_axis_tvalid = '0' and s00_axis_tlast = '0') then
        stop_cnt <= stop_cnt + 1;
    elsif (s00_axis_tvalid = '1' and axis_tready = '1') then
        stop_cnt <= 0;
    end if;
end if;
end process;

pipeline1:process(s00_axis_aclk)
begin
if(rising_edge(s00_axis_aclk)) then
    if start = '1' or s00_axis_tvalid = '1' then
        r_data <= to_integer(unsigned(s00_axis_tdata(23 downto 16)))*76; --R
        g_data <= to_integer(unsigned(s00_axis_tdata(15 downto 8)))*150; --G
        b_data <= to_integer(unsigned(s00_axis_tdata(7 downto 0)))*29; --B
        data_stage1 <= '1';
    else
        data_stage1 <= '0';
    end if;
    
end if;
end process;

pipeline2:process(s00_axis_aclk)
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

pipeline3:process(s00_axis_aclk)
begin
if(rising_edge(s00_axis_aclk)) then
    if(data_stage2 = '1') then
        gray_value <= shift_right(gray_data,8);
        data_stage3 <= '1';
    else 
        data_stage3 <= '0';
    end if;
end if;
end process;

--------  Begin Line Buffer

linear_buffer:process(s00_axis_aclk) is
begin
if rising_edge(s00_axis_aclk) then
	if (data_stage3 = '1') then
	    inMat1    <= to_integer(unsigned(gray_value))&inMat1(0 to inMat1'length-2);
		inMat2    <= inMat1(image_width - 1)&inMat2(0 to inMat2'length-2);
		inMat3    <= inMat2(image_width - 1)&inMat3(0 to inMat3'length-2);
		data_stage4 <= '1';
		counter <= counter + 1;
	else 
		data_stage4 <= '0';
	    	inMat1 <= (others => 0);
	    	inMat2 <= (others => 0);
	    	inMat3 <= (others => 0);
		counter <= 0; 
	end if;
end if;
end process;

--------  End Line Buffer

-------- Begin Convolution
conv:process(s00_axis_aclk) is
variable r : integer := 0;
variable c : integer := 0;
begin   
if rising_edge(s00_axis_aclk) then
	if (data_stage4 = '1') then
		if counter > image_width + 1  then -- check if pixel value has reached second row second column
        		if r = 0 then
                		if c = 0 then
                        		x1 <= inMat1(0)*m1;
                        		x2 <= inMat1(1)*m2;
                        		x3 <= inMat1(2)*0;
                        		x4 <= inMat2(0)*m4;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*0;
                        		x7 <= inMat3(0)*0;
                        		x8 <= inMat3(1)*0;
                        		x9 <= inMat3(2)*0;
                        		 
                        		y1 <= inMat1(0)*k1;
                        		y2 <= inMat1(1)*k2;
                        		y3 <= inMat1(2)*0;
                        		y4 <= inMat2(0)*k4;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*0;
                        		y7 <= inMat3(0)*0;
                        		y8 <= inMat3(1)*0;
                        		y9 <= inMat3(2)*0;
                        		
					            data_stage5 <= '1';
                        		c := c+1;
                      
                    		elsif c = image_width-1 then
                        		x1 <= inMat1(0)*0;
                        		x2 <= inMat1(1)*m2;
                        		x3 <= inMat1(2)*m3;
                        		x4 <= inMat2(0)*0;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*m6;
                        		x7 <= inMat3(0)*0;
                       		 	x8 <= inMat3(1)*0;
                        		x9 <= inMat3(2)*0;

                        		y1 <= inMat1(0)*0;
                        		y2 <= inMat1(1)*k2;
                        		y3 <= inMat1(2)*k3;
                        		y4 <= inMat2(0)*0;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*k6;
                        		y7 <= inMat3(0)*0;
                       		 	y8 <= inMat3(1)*0;
                        		y9 <= inMat3(2)*0;
                        		                        	
					            data_stage5 <= '1';
                        		c := 0;
                        		r := r+1;    
                     
                    		else 
                        		x1 <= inMat1(0)*m1;
                        		x2 <= inMat1(1)*m2;
                        		x3 <= inMat1(2)*m3;
                        		x4 <= inMat2(0)*m4;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*m6;
                        		x7 <= inMat3(0)*0;
                        		x8 <= inMat3(1)*0;
                        		x9 <= inMat3(2)*0;

                        		y1 <= inMat1(0)*k1;
                        		y2 <= inMat1(1)*k2;
                        		y3 <= inMat1(2)*k3;
                        		y4 <= inMat2(0)*k4;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*k6;
                        		y7 <= inMat3(0)*0;
                        		y8 <= inMat3(1)*0;
                        		y9 <= inMat3(2)*0;
                        		                        	
					            data_stage5 <= '1';
                        		c  := c+1;
                    		end if;
 
                	elsif r = image_height-1 then
                		if c = 0 then
                        		x1 <= inMat1(0)*0;
                        		x2 <= inMat1(1)*0;
                        		x3 <= inMat1(2)*0;
                        		x4 <= inMat2(0)*m4;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*0;
                        		x7 <= inMat3(0)*m7;
                        		x8 <= inMat3(1)*m8;
                        		x9 <= inMat3(2)*0;

                        		y1 <= inMat1(0)*0;
                        		y2 <= inMat1(1)*0;
                        		y3 <= inMat1(2)*0;
                        		y4 <= inMat2(0)*k4;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*0;
                        		y7 <= inMat3(0)*k7;
                        		y8 <= inMat3(1)*k8;
                        		y9 <= inMat3(2)*0;
                        		                        
					            data_stage5 <= '1';
                        		c := c+1;
                        
                    		elsif c = image_width-1 then
                        		x1 <= inMat1(0)*0;
                        		x2 <= inMat1(1)*0;
                        		x3 <= inMat1(2)*0;
                        		x4 <= inMat2(0)*0;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*m6;
                        		x7 <= inMat3(0)*0;
                        		x8 <= inMat3(1)*m8;
                        		x9 <= inMat3(2)*m9;

                        		y1 <= inMat1(0)*0;
                        		y2 <= inMat1(1)*0;
                        		y3 <= inMat1(2)*0;
                        		y4 <= inMat2(0)*0;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*k6;
                        		y7 <= inMat3(0)*0;
                        		y8 <= inMat3(1)*k8;
                        		y9 <= inMat3(2)*k9;
                        		                        	
					            data_stage5 <= '1';
                        		c := 0;
                        		r := 0;
                        
                    		else 
                        		x1 <= inMat1(0)*0;
                        		x2 <= inMat1(1)*0;
                        		x3 <= inMat1(2)*0;
                        		x4 <= inMat2(0)*m4;
                        		x5 <= inMat2(1)*m5;
                        		x6 <= inMat2(2)*m6;
                        		x7 <= inMat3(0)*m7;
                        		x8 <= inMat3(1)*m8;
                        		x9 <= inMat3(2)*m9;

                        		y1 <= inMat1(0)*0;
                        		y2 <= inMat1(1)*0;
                        		y3 <= inMat1(2)*0;
                        		y4 <= inMat2(0)*k4;
                        		y5 <= inMat2(1)*k5;
                        		y6 <= inMat2(2)*k6;
                        		y7 <= inMat3(0)*k7;
                        		y8 <= inMat3(1)*k8;
                        		y9 <= inMat3(2)*k9;
                        		                        	
					            data_stage5 <= '1';
                        		c := c+1;
                        
                    		end if;

                	else
                    		if c = 0 then
                	        	x1 <= inMat1(0)*m1;
                	        	x2 <= inMat1(1)*m2;
                	        	x3 <= inMat1(2)*0;
                	        	x4 <= inMat2(0)*m4;
                	        	x5 <= inMat2(1)*m5;
                	        	x6 <= inMat2(2)*0;
                	        	x7 <= inMat3(0)*m7;
                	        	x8 <= inMat3(1)*m8;
                	        	x9 <= inMat3(2)*0;

                	        	y1 <= inMat1(0)*k1;
                	        	y2 <= inMat1(1)*k2;
                	        	y3 <= inMat1(2)*0;
                	        	y4 <= inMat2(0)*k4;
                	        	y5 <= inMat2(1)*k5;
                	        	y6 <= inMat2(2)*0;
                	        	y7 <= inMat3(0)*k7;
                	        	y8 <= inMat3(1)*k8;
                	        	y9 <= inMat3(2)*0;
                	        	                        
					            data_stage5 <= '1';
                	        	c := c+1;
                        
                	    	elsif c = image_width-1 then
                	    	    x1 <= inMat1(0)*0;
                	    	   	x2 <= inMat1(1)*m2;
                	    	   	x3 <= inMat1(2)*m3;
                	    	   	x4 <= inMat2(0)*0;
                	    	   	x5 <= inMat2(1)*m5;
                	        	x6 <= inMat2(2)*m6;
                	   	    	x7 <= inMat3(0)*0;
                	   	    	x8 <= inMat3(1)*m8;
                	   	    	x9 <= inMat3(2)*m9;         

                	    	    y1 <= inMat1(0)*0;
                	    	   	y2 <= inMat1(1)*k2;
                	    	   	y3 <= inMat1(2)*k3;
                	    	   	y4 <= inMat2(0)*0;
                	    	   	y5 <= inMat2(1)*k5;
                	        	y6 <= inMat2(2)*k6;
                	   	    	y7 <= inMat3(0)*0;
                	   	    	y8 <= inMat3(1)*k8;
                	   	    	y9 <= inMat3(2)*k9;  
                	   	    	      
                	        	data_stage5 <= '1';
                	    	  	c := 0;
                	    	   	r := r+1;
                        
                	    	else
                	        	x1 <= inMat1(0)*m1;
                	        	x2 <= inMat1(1)*m2;
                	        	x3 <= inMat1(2)*m3;
                	        	x4 <= inMat2(0)*m4;
                	        	x5 <= inMat2(1)*m5;
                	        	x6 <= inMat2(2)*m6;
                	        	x7 <= inMat3(0)*m7;
                	        	x8 <= inMat3(1)*m8;
                	        	x9 <= inMat3(2)*m9;

                	        	y1 <= inMat1(0)*k1;
                	        	y2 <= inMat1(1)*k2;
                	        	y3 <= inMat1(2)*k3;
                	        	y4 <= inMat2(0)*k4;
                	        	y5 <= inMat2(1)*k5;
                	        	y6 <= inMat2(2)*k6;
                	        	y7 <= inMat3(0)*k7;
                	        	y8 <= inMat3(1)*k8;
                	        	y9 <= inMat3(2)*k9;

					            data_stage5 <= '1';
                	        	c := c+1;
                	        
                	    	end if;  
               		end if;          
            data_stage5 <= '1';
        end if;
    else 
		data_stage5 <= '0';   
    end if;                
end if;
end process;

prefinal_stage: process (s00_axis_aclk) is
begin
if rising_edge(s00_axis_aclk) then
	if data_stage5 = '1' then
		sumy <= x1+x2+x3+x4+x5+x6+x7+x8+x9;
	    sumx <= y1+y2+y3+y4+y5+y6+y7+y8+y9;
		data_stage6 <= '1';
	else 
		data_stage6 <= '0';
	end if;
end if;
end process;

final_stage: process (s00_axis_aclk) is
begin
if rising_edge(s00_axis_aclk) then
	if data_stage6 = '1' then
		sum <= sumx+sumy;    
		data_stage7 <= '1';
	else   
		data_stage7 <= '0';
	end if;
end if;
end process;
        
------ End of Convolution

data_limits:process (s00_axis_aclk) is
begin
if (rising_edge(s00_axis_aclk)) then
	if data_stage7 = '1' then
	   if (sum <= 127 ) then
		  m_axis_tdata <= (others => '0');  
	   elsif (sum >= 255) then
	      m_axis_tdata <= (others => '1');
	   else
	      m_axis_tdata <= (others => '0');
	   end if;
	   fifo_rd <= '1';
	else 
	   fifo_rd <= '0';
	end if;
end if;
end process;






m00_axis_tdata <= m_axis_tdata;
m00_axis_tlast <= s_axis_tlast;
m00_axis_tvalid <= s_axis_tvalid;
m00_axis_tuser <= s_axis_tuser;          


s00_axis_tready <= axis_tready;

end arch_imp;

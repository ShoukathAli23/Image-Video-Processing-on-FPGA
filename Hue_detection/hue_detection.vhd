library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Colour_Filter_v1_0_AXIS is
	generic (
		-- Users to add parameters here
        	C_S_AXI_DATA_WIDTH	: integer	:= 32;		
		-- User parameters ends
		-- Do not modify the parameters beyond this line


		-- Parameters of Axi Slave Bus Interface S00_AXIS
		C_S_AXIS_TDATA_WIDTH	: integer	:= 24;

		-- Parameters of Axi Master Bus Interface M00_AXIS
		C_M_AXIS_TDATA_WIDTH	: integer	:= 24;
		C_M_AXIS_START_COUNT	: integer	:= 32
	);
	port (
		-- Users to add ports here
		--mode         : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        	lower_limit  : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        	upper_limit  : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		-- User ports ends
		-- Do not modify the ports beyond this line

		S_AXIS_ACLK	: in std_logic;
		S_AXIS_ARESETN	: in std_logic;
		
		S_AXIS_TREADY	: out std_logic;
		S_AXIS_TDATA	: in std_logic_vector(C_S_AXIS_TDATA_WIDTH-1 downto 0);
		S_AXIS_TUSER    : in std_logic_vector(0 downto 0);
		S_AXIS_TLAST	: in std_logic;
		S_AXIS_TVALID	: in std_logic;
		
		M_AXIS_ACLK	: in std_logic;
		M_AXIS_ARESETN	: in std_logic;
		
		M_AXIS_TVALID	: out std_logic;
		M_AXIS_TDATA	: out std_logic_vector(C_M_AXIS_TDATA_WIDTH-1 downto 0);
		M_AXIS_TUSER    : out std_logic_vector(0 downto 0);
		M_AXIS_TLAST	: out std_logic;
		M_AXIS_TREADY	: in std_logic		

	);
end Colour_Filter_v1_0_AXIS;

architecture arch_imp of Colour_Filter_v1_0_AXIS is
		 
	  signal axis_tlast1, axis_tlast2, axis_tlast3, axis_tlast4, axis_tlast5, axis_tlast6	:  std_logic;
      signal axis_tvalid1, axis_tvalid2, axis_tvalid3, axis_tvalid4, axis_tvalid5, axis_tvalid6	:  std_logic;
      signal axis_tuser1, axis_tuser2, axis_tuser3, axis_tuser4, axis_tuser5, axis_tuser6 :  std_logic_vector(0 downto 0);
      
      signal red_pixel1, red_pixel2, red_pixel3, red_pixel4, red_pixel5, red_pixel6 : integer range 0 to 255; 
      signal green_pixel1, green_pixel2, green_pixel3, green_pixel4, green_pixel5, green_pixel6 : integer range 0 to 255; 
      signal blue_pixel1, blue_pixel2, blue_pixel3, blue_pixel4, blue_pixel5, blue_pixel6 : integer range 0 to 255; 
      
      signal max, min, diff, diff1, diff2 : integer range 0 to 255;
      signal num : signed(15 downto 0);
      
      signal num_product : integer;
      signal add_product : integer; 
      signal low_limit, up_limit : integer;
       
      signal start_stage2, start_stage3, start_stage4, start_stage5, start_stage6 : std_logic;
      
      signal max_val1, max_val2 : std_logic_vector(1 downto 0);
      signal hue, h360: integer;
           
begin

S_AXIS_TREADY <= M_AXIS_TREADY;

-- stage 1
----------------------------------------------------------------------
---------------- Hue calculation pipeline-----------------------------
----------------------------------------------------------------------

---------------- read R, G, B pixels

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if S_AXIS_ARESETN = '0' then
        blue_pixel1 <= 0;
        green_pixel1 <= 0; 
        red_pixel1 <= 0;
        start_stage2 <= '0'; 
    else
        blue_pixel1 <= to_integer(unsigned(S_AXIS_TDATA(23 downto 16)));
        green_pixel1 <= to_integer(unsigned(S_AXIS_TDATA(15 downto 8)));
        red_pixel1 <= to_integer(unsigned(S_AXIS_TDATA(7 downto 0)));
        start_stage2 <= '1';
    end if;
end if;
end process;


-- stage 2
----------------  find max and min among R, G, B
process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        max <= 0;
        min <= 0;         
    elsif(start_stage2 = '1') then
        if (red_pixel1 > blue_pixel1) and (red_pixel1 > green_pixel1) and (blue_pixel1 > green_pixel1) then
            max <= red_pixel1;
            min <= green_pixel1;
            max_val1 <= "01";
        elsif (red_pixel1 > blue_pixel1) and (red_pixel1 > green_pixel1) and (green_pixel1 > blue_pixel1) then
            max <= red_pixel1;
            min <= blue_pixel1;
            max_val1 <= "01";
        elsif (red_pixel1 = green_pixel1) and (green_pixel1 > blue_pixel1) then
            max <= red_pixel1;
            min <= blue_pixel1;
            max_val1 <= "01";
        elsif (red_pixel1 = blue_pixel1) and (blue_pixel1 > green_pixel1) then
            max <= red_pixel1;
            min <= green_pixel1;
            max_val1 <= "01";
            
        elsif (green_pixel1 > red_pixel1) and (green_pixel1 > blue_pixel1) and (red_pixel1 > blue_pixel1) then
            max <= green_pixel1;
            min <= blue_pixel1;
            max_val1 <= "10";
        elsif (green_pixel1 > red_pixel1) and (green_pixel1 > blue_pixel1) and (blue_pixel1 > red_pixel1) then
            max <= green_pixel1;
            min <= red_pixel1;  
            max_val1 <= "10";          
        elsif (green_pixel1 = red_pixel1) and (red_pixel1 > blue_pixel1) then
            max <= green_pixel1;
            min <= blue_pixel1;
            max_val1 <= "10";
        elsif (green_pixel1 = blue_pixel1) and (blue_pixel1 > red_pixel1) then
            max <= green_pixel1;
            min <= red_pixel1;
            max_val1 <= "10";
            
        elsif (blue_pixel1 > red_pixel1) and (blue_pixel1 > green_pixel1) and (red_pixel1 > green_pixel1) then
            max <= blue_pixel1;
            min <= green_pixel1;
            max_val1 <= "11";
        elsif (blue_pixel1 > red_pixel1) and (blue_pixel1 > green_pixel1) and (green_pixel1 > red_pixel1) then
            max <= blue_pixel1;
            min <= red_pixel1;
            max_val1 <= "11";            
        elsif (blue_pixel1 = red_pixel1) and (red_pixel1 > green_pixel1) then
            max <= blue_pixel1;
            min <= green_pixel1;
            max_val1 <= "11";
        elsif (blue_pixel1 = green_pixel1) and (green_pixel1 > red_pixel1) then
            max <= blue_pixel1;
            min <= red_pixel1;
            max_val1 <= "11";
            
        elsif (red_pixel1 = green_pixel1) and (red_pixel1 = blue_pixel1) then
            max <= red_pixel1;
            min <= green_pixel1;
            max_val1 <= "01";
        end if;
    end if;
end if;
end process;

-- stage 3
--------------------  calculate numerator and dinominator for hue calculation
--------  if Rmax then h = (num/diff)*60
--------  if Gmax then h = 120 + (num/diff)*60
--------  if Bmax then h = 240 +  (num/ diff)*60
--------  if diff = 0 then h = 0
--------  if h<0 the h = 360 + h
--------------- what we do to elemnate division by diff
--------------- we calculatet h*diff = (?360*diff) + (0/120/240)*diff + num*60 

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        num <= (others => '0');
        diff <= 0;       
    elsif(start_stage3 = '1') then
        if max_val1 = "01" then
            num <= to_signed(green_pixel2 - blue_pixel2,num'length);
            diff <= max - min;
        elsif max_val1 = "10" then
            num <= to_signed(blue_pixel2 - red_pixel2,num'length);
            diff <= max - min;
        elsif max_val1 = "11" then 
            num <= to_signed(red_pixel2 - green_pixel2,num'length);
            diff <= max - min;
        else 
            num <=  num;
            diff <= diff;
        end if;
        max_val2 <= max_val1;
    end if;
end if;
end process;

-- stage 4

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        num_product <= 0;
        add_product <= 0; 
        diff1 <= 0;
        h360 <= 0;   
    elsif(start_stage4 = '1') then
        num_product <= to_integer(num*to_signed(60,num'length));
        diff1 <= diff;
        h360 <= 360*diff;
        if(max_val2 = "01") then
            add_product <= 0;
        elsif(max_val2 = "10") then
            add_product <= 120*diff;
        elsif(max_val2 = "11") then
            add_product <= 240*diff;
        end if;  
    end if;
end if;
end process;

-- stage 5

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        hue <= 0;   
        diff2 <= diff1;
        low_limit <= 0;
        up_limit <= 0;
    elsif(start_stage5 = '1') then
        diff2 <= diff1;
        low_limit <= to_integer(unsigned(lower_limit))*diff1;
        up_limit <= to_integer(unsigned(upper_limit))*diff1;
        if (num_product < 0) then
            hue <= h360 + add_product + num_product;
        else
            hue <= add_product + num_product;
        end if;
    end if;
end if;
end process;

-- stage 6

process(M_AXIS_ACLK)
begin
if(rising_edge(M_AXIS_ACLK)) then
    if (M_AXIS_ARESETN = '0') then
        M_AXIS_TDATA <= (others => '0'); 
    elsif(start_stage6 = '1') then
        if diff2 = 0 then
            M_AXIS_TDATA <= (others => '0');        
        elsif diff2 > 0 and hue > low_limit and hue < up_limit then
            M_AXIS_TDATA(23 downto 16) <= std_logic_vector(to_unsigned(blue_pixel5, 8));
            M_AXIS_TDATA(15 downto 8) <= std_logic_vector(to_unsigned(green_pixel5, 8));
            M_AXIS_TDATA(7 downto 0) <= std_logic_vector(to_unsigned(red_pixel5, 8));
         elsif low_limit = 0 and up_limit = 0 then
            M_AXIS_TDATA(23 downto 16) <= std_logic_vector(to_unsigned(blue_pixel5, 8));
            M_AXIS_TDATA(15 downto 8) <= std_logic_vector(to_unsigned(green_pixel5, 8));
            M_AXIS_TDATA(7 downto 0) <= std_logic_vector(to_unsigned(red_pixel5, 8));
         else            
            M_AXIS_TDATA <= (others => '0');
         end if;
    end if;
end if;
end process;

--------------------------------------------------------------------------------------
------------- data and axis signals pipeline ------------------
------------------------------------------------------------------------

-------- stage 1
process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        axis_tvalid1 <= '0';
        axis_tlast1 <= '0';
        axis_tuser1 <= (others => '0');
    else  
        axis_tvalid1 <= S_AXIS_TVALID;
        axis_tlast1 <= S_AXIS_TLAST;
        axis_tuser1 <= S_AXIS_TUSER;   
    end if;
end if;
end process; 

------------stage 2
process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        blue_pixel2 <= 0;
        green_pixel2 <= 0; 
        red_pixel2 <= 0;
        start_stage3 <= '0';         
    elsif(start_stage2 = '1') then
        blue_pixel2 <= blue_pixel1;
        green_pixel2 <= green_pixel1;
        red_pixel2 <= red_pixel1;
        start_stage3 <= '1';
    end if;
end if;
end process;

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        axis_tvalid2 <= '0';
        axis_tlast2 <= '0';
        axis_tuser2 <= (others => '0');
    elsif (start_stage2 = '1') then  
        axis_tvalid2 <= axis_tvalid1;
        axis_tlast2 <= axis_tlast1;
        axis_tuser2 <= axis_tuser1;   
    end if;
end if;
end process;

---------- stage 3

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        blue_pixel3 <= 0;
        green_pixel3 <= 0; 
        red_pixel3 <= 0;
        start_stage4 <= '0';         
    elsif(start_stage3 = '1') then
        blue_pixel3 <= blue_pixel2;
        green_pixel3 <= green_pixel2;
        red_pixel3 <= red_pixel2;
        start_stage4 <= '1';
    end if;
end if;
end process;


process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        axis_tvalid3 <= '0';
        axis_tlast3 <= '0';
        axis_tuser3 <= (others => '0');
    elsif (start_stage3 = '1') then  
        axis_tvalid3 <= axis_tvalid2;
        axis_tlast3 <= axis_tlast2;
        axis_tuser3 <= axis_tuser2;   
    end if;
end if;
end process;

-------- stage 4

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        blue_pixel4 <= 0;
        green_pixel4 <= 0; 
        red_pixel4 <= 0;
        start_stage5 <= '0';         
    elsif(start_stage4 = '1') then
        blue_pixel4 <= blue_pixel3;
        green_pixel4 <= green_pixel3;
        red_pixel4 <= red_pixel3;
        start_stage5 <= '1';
    end if;
end if;
end process;

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        axis_tvalid4 <= '0';
        axis_tlast4 <= '0';
        axis_tuser4 <= (others => '0');
    elsif (start_stage4 = '1') then  
        axis_tvalid4 <= axis_tvalid3;
        axis_tlast4 <= axis_tlast3;
        axis_tuser4 <= axis_tuser3;   
    end if;
end if;
end process;

---------- stage 5

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        blue_pixel5 <= 0;
        green_pixel5 <= 0; 
        red_pixel5 <= 0;
        start_stage6 <= '0';         
    elsif(start_stage5 = '1') then
        blue_pixel5 <= blue_pixel4;
        green_pixel5 <= green_pixel4;
        red_pixel5 <= red_pixel4;
        start_stage6 <= '1';
    end if;
end if;
end process;

process(S_AXIS_ACLK)
begin
if(rising_edge(S_AXIS_ACLK)) then
    if (S_AXIS_ARESETN = '0') then
        axis_tvalid5 <= '0';
        axis_tlast5 <= '0';
        axis_tuser5 <= (others => '0');
    elsif (start_stage5 = '1') then  
        axis_tvalid5 <= axis_tvalid4;
        axis_tlast5 <= axis_tlast4;
        axis_tuser5 <= axis_tuser4;   
    end if;
end if;
end process;

------------  stage 6

process(M_AXIS_ACLK)
begin
if(rising_edge(M_AXIS_ACLK)) then
    if (M_AXIS_ARESETN = '0') then
        M_AXIS_TVALID <= '0';
        M_AXIS_TLAST <= '0';
        M_AXIS_TUSER <= (others => '0');
    elsif (start_stage6 = '1') then  
        M_AXIS_TVALID <= axis_tvalid5;
        M_AXIS_TLAST <= axis_tlast5;
        M_AXIS_TUSER <= axis_tuser5;   
    end if;
end if;
end process;


end arch_imp;


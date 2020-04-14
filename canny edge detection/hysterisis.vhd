-- Name			: Shoukath Ali Mohammad
-- Title		: hysterisis
-- Description 	: check for the weak pixels near trong pixels and make them strong

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity hysteresis is
	generic (
			data_width 		: integer := 32;
			image_width 	: integer := 1920;
			image_height	: integer := 1080
	);
	port (	
			aclk 		    : in  std_logic;
			aresetn 		: in  std_logic;			
			
			dTh_tvalid 	    : in  std_logic;
			dTh_tlast 		: in  std_logic;
			dTh_tdata 		: in  std_logic_vector(data_width -1 downto 0);
            dTh_tready      : out std_logic;
            dTh_tkeep       : in std_logic_vector(data_width/8 -1 downto 0);
			
			hyst_tready 	: in  std_logic;
			hyst_tvalid 	: out std_logic;
			hyst_tlast 		: out std_logic;
			hyst_tkeep      : out std_logic_vector(data_width/8 -1 downto 0);
			hyst_tdata 		: out std_logic_vector(data_width -1 downto 0)
	   );
			
end hysteresis;

architecture Behavioral of hysteresis is

	type line_buffer is array (0 to image_width -4) of integer;
	signal 	row_buffer1 	: line_buffer;
	signal  row_buffer2 	: line_buffer;

    type axis_tvalid_buffer is array (0 to image_width -1) of std_logic;
	signal 	tvalid 	: axis_tvalid_buffer;
	signal 	tlast 	: axis_tvalid_buffer;
	
		
	signal tvalid1, tvalid2, tvalid3, tvalid4, tvalid5, tvalid6, tvalid7, tvalid_1, tvalid_2 : std_logic;
	signal tlast1, tlast2, tlast3, tlast4, tlast5, tlast6, tlast7, tlast_1, tlast_2 : std_logic;
	
	signal 	p9, p8, p7 		: integer := 0;
	signal 	p6, p5, p4 		: integer := 0;
	signal 	p3, p2, p1 		: integer := 0;

	signal 	t9, t8, t7 	: integer := 0;
	signal 	t6, t5, t4 	: integer := 0;
	signal 	t3, t2, t1 	: integer := 0;

    signal current_pixel : integer;
	signal row, col    : integer; 
    
    constant strong : integer range 0 to 255 := 255;
    
begin
	


	-- buffer data
	hyst_stage1: process(aclk)
	begin
		if rising_edge(aclk) then
			if aresetn = '0' then
				p9 		<= 0;     p8 	<= 0;   p7 		<= 0;     row_buffer1 <= (others => 0);
				
				p6 		<= 0;     p5 	<= 0;   p4 		<= 0;     row_buffer2 <= (others => 0);
				
				p3		<= 0;     p2 	<= 0;   p1		<= 0;	

                tvalid <= (others => '0');  tvalid_1 <= '0'; tvalid_2 <= '0';
                tlast  <= (others => '0');  tlast_1  <= '0'; tlast_2  <= '0';
			elsif hyst_tready = '1' then
				p9 		<= to_integer(unsigned(dTh_tdata(7 downto 0)));      p8 	<= p9;    p7 	<= p8;    row_buffer1 <= p7 & row_buffer1(0 to row_buffer1'length-2);
					
				p6 		<= row_buffer1(row_buffer1'length - 1);   p5 	<= p6;    p4 	<= p5;    row_buffer2 <= p4 & row_buffer2(0 to row_buffer2'length-2);
					
				p3		<= row_buffer2(row_buffer2'length - 1);   p2 	<= p3;    p1	<= p2;

                tvalid <= dTh_tvalid & tvalid(0 to tvalid'length-2); 
                tvalid_1 <= tvalid(tvalid'length -1); tvalid_2 <= tvalid_1;
                
                tlast <= dTh_tlast & tlast(0 to tlast'length-2); 
                tlast_1<= tlast(tlast'length -1); tlast_2 <= tlast_1;
			end if;
		end if;
	end process;				

	row_col: process(aclk)	
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
		      row <= 0;
			  col <= 0;
		   elsif hyst_tready = '1' then
		      if  tvalid_2 = '1' then
                 if col = image_width -1 then 
                        col <= 0;
                        if row = image_height-1 then 
                            row <= 0;
                        else 
                            row <= row + 1;
                        end if;
                  else 
                        col <= col + 1;
                  end if;		           
		      end if;
		   end if;
	end if;
end process;

	hyst_stage2: process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
				t9 <= 0; 	t8 <= 0;  	t7 <= 0;
				t6 <= 0; 	t5 <= 0; 	t4 <= 0;
				t3 <= 0; 	t2 <= 0; 	t1 <= 0;	 
				tvalid1 <= '0';
				tlast1  <= '0';
			elsif hyst_tready = '1' then 
				tvalid1 <= tvalid_2;
				tlast1  <= tlast_2;
			     if  tvalid_2 = '1' then
                    if row = 0 then
                        if col = 0 then
                            t9 <= p9; 	t8 <= p8;  	t7 <= 0;
                            t6 <= p6; 	t5 <= p5; 	t4 <= 0;
                            t3 <= 0; 	t2 <= 0; 	t1 <= 0;
                        elsif col = image_width -1 then
                            t9 <= 0;  	t8 <= p8;  	t7 <= p7;
                            t6 <= 0; 	t5 <= p5; 	t4 <= p4;
                            t3 <= 0;	t2 <= 0; 	t1 <= 0;
                        else
                            t9 <= p9;  	t8 <= p8;  	t7 <= p7;
                            t6 <= p6; 	t5 <= p5; 	t4 <= p4;
                            t3 <= 0;	t2 <= 0; 	t1 <= 0;
                        end if;
                        
                    elsif row = image_height - 1 then
                        if col = 0 then
                        
                            t9 <= 0; 	t8 <= 0; 	t7 <= 0;
                            t6 <= p6; 	t5 <= p5; 	t4 <= 0;
                            t3 <= p3; 	t2 <= p2;  	t1 <= 0;
                        elsif col = image_width -1 then
                            t9 <= 0; 	t8 <= 0; 	t7 <= 0;
                            t6 <= 0; 	t5 <= p5; 	t4 <= p4;
                            t3 <= 0;	t2 <= p2;  	t1 <= p1;
                        else
                            t9 <= 0; 	t8 <= 0; 	t7 <= 0;
                            t6 <= p6; 	t5 <= p5; 	t4 <= p4;
                            t3 <= p3; 	t2 <= p2;  	t1 <= p1;
                        end if;   
                    else
                        if col = 0 then
                            t9 <= p9; 	t8 <= p8; 	t7 <= 0;
                            t6 <= p6; 	t5 <= p5; 	t4 <= 0;
                            t3 <= p3;	t2 <= p2; 	t1 <= 0;
                        elsif col = image_width -1 then
                            t9 <= 0; 	t8 <= p8; 	t7 <= p7;
                            t6 <= 0; 	t5 <= p5; 	t4 <= p4;
                            t3 <= 0;	t2 <= p2; 	t1 <= p1;
                         else
                            t9 <= p9; 	t8 <= p8; 	t7 <= p7;
                            t6 <= p6; 	t5 <= p5; 	t4 <= p4;
                            t3 <= p3;	t2 <= p2; 	t1 <= p1;
                         end if;  
                    end if;
                end if;
		   end if;
		end if;
	end process;

process(aclk)
	begin
		if rising_edge(aclk) then
	       if aresetn = '0' then
				current_pixel <= 0;
				tvalid2 <= '0';
				tlast2  <= '0';
		   elsif hyst_tready = '1' then
		      if t5 > 0 then
				if t9 = strong or t8 = strong or t7 = strong or t6 = strong or t4 = strong or t3 = strong or t2 = strong or t1 = strong then
				    current_pixel <= strong;
				else 
				    current_pixel <= 0;
				end if;
			  else 
			     current_pixel <= 0;
			  end if;
				tvalid2 <= tvalid1;
				tlast2  <= tlast1;
		   end if;
		end if;
	end process;


		
hyst_tdata(7 downto   0)	<= 	std_logic_vector(to_unsigned(current_pixel,8));
hyst_tdata(15 downto  8)	<= 	std_logic_vector(to_unsigned(current_pixel,8));
hyst_tdata(23 downto 16)	<= 	std_logic_vector(to_unsigned(current_pixel,8));		
hyst_tdata(31 downto 24)    <= (others => '0');	
	
hyst_tvalid 	<= tvalid2;
hyst_tlast 		<= tlast2;
hyst_tkeep      <= (others => '1');
    
dTh_tready      <= hyst_tready;
	
end architecture Behavioral;

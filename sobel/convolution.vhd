-- Name			: Shoukath Ali Mohammad
-- Title		: convolution
-- Description 	: apply convolution on the streaming image pixel data

-- Name			: Shoukath Ali Mohammad
-- Title		: convolution
-- Description 	: apply convolution on the streaming image pixel data

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity intensity_gradient is
	generic (
			data_width 		: integer := 24;
			image_width 	: integer := 9;
			image_height	: integer := 9
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
			
			en_conv			: in  std_logic;			
			
			gray_tvalid 	: in  std_logic;
			gray_tlast 		: in  std_logic;
--			gray_tuser 		: in  std_logic_vector(0 downto 0);
			gray_tdata 		: in  std_logic_vector(data_width/4 -1 downto 0);
            gray_tready     : out std_logic;
            gray_tkeep      : in std_logic_vector(data_width/8 -1 downto 0);
            
			aclk_out		: in  std_logic;
			aresetn_out		: in  std_logic;
			
			conv_tready 	: in  std_logic;
			conv_tvalid 	: out std_logic;
			conv_tlast 		: out std_logic;
--			conv_tuser 		: out std_logic_vector(0 downto 0);
			conv_tkeep      : out std_logic_vector(data_width/8 -1 downto 0);
			conv_tdata 		: out std_logic_vector(data_width-1 downto 0)
			
	);
end entity intensity_gradient;

architecture conv of intensity_gradient is 

	constant wait_time		: integer := 32; -- standard wait time for axis 
	signal 	start_delay 	: std_logic_vector(5 downto 0);

	signal start_conv	: std_logic;
    signal stage1, stage2, stage3 : std_logic;
    
	type line_buffer is array (0 to image_width -4) of integer;
	signal 	row_buffer1 	: line_buffer := (others => 0);
	signal  row_buffer2 	: line_buffer := (others => 0);

    type axis_tvalid_buffer is array (0 to image_width +2) of std_logic;
	signal 	tvalid 	: axis_tvalid_buffer := (others => '0');
	
	type axis_tlast_buffer is array (0 to image_width +2) of std_logic;
	signal 	tlast 	: axis_tlast_buffer := (others => '0');
	
--    type axis_tuser_buffer is array (0 to image_width +2) of std_logic_vector(0 downto 0);
--	signal 	tuser 	: axis_tuser_buffer := (others => (others => '0'));

    type axis_tkeep_buffer is array (0 to image_width +2) of std_logic_vector(data_width/8 -1 downto 0);
	signal 	tkeep 	: axis_tkeep_buffer := (others => (others => '0'));
		
	signal tvalid1, tvalid2, tvalid3 : std_logic;
	signal tlast1, tlast2, tlast3 : std_logic;
	
--	signal tuser1, tuser2, tuser3 : std_logic_vector(0 downto 0);
	
	signal tkeep1, tkeep2, tkeep3 : std_logic_vector(data_width/8 -1 downto 0);
	
	signal 	p9, p8, p7 		: integer := 0;
	signal 	p6, p5, p4 		: integer := 0;
	signal 	p3, p2, p1 		: integer := 0;

	signal 	wx9, wx8, wx7 	: integer := 0;
	signal 	wx6, wx5, wx4 	: integer := 0;
	signal 	wx3, wx2, wx1 	: integer := 0;

	signal 	wy9, wy8, wy7 	: integer := 0;
	signal 	wy6, wy5, wy4 	: integer := 0;
	signal 	wy3, wy2, wy1 	: integer := 0;

	signal tvalid_ctl 		: std_logic;
    signal sumx, sumy, sum  : integer;
	signal row, col, pre_cnt: integer;
	------- Filter ----------------------------------------------------
	------- Sobel Gy
	constant k9 : integer := -1; constant k8 : integer := -2; constant k7 : integer := -1; 
	constant k6 : integer :=  0; constant k5 : integer :=  0; constant k4 : integer :=  0;  
	constant k3 : integer :=  1; constant k2 : integer :=  2; constant k1 : integer :=  1;

	------- Sobel Gx
	constant m9 : integer := 1; constant m8 : integer :=  0; constant m7 : integer :=  -1;
	constant m6 : integer := 2; constant m5 : integer :=  0; constant m4 : integer :=  -2;
	constant m3 : integer := 1; constant m2 : integer :=  0; constant m1 : integer :=  -1;

------- Filter ----------------------------------------------------

-- map 
--              k9 k8 k7       p9 p8 p7  row_fifo1 
--				k6 k5 k4       p6 p5 p4  row_fifo2
--				k3 k2 k1       p3 p2 p1

	constant fifo_depth 	: integer := image_width + 10;
	signal fifo_rd, fifo_wr : std_logic;
	
begin
	

	-- buffer data
	conv_stage1: process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
				p9 		<= 0;     p8 	<= 0;   p7 		<= 0;     row_buffer1 <= (others => 0);
				
				p6 		<= 0;     p5 	<= 0;   p4 		<= 0;     row_buffer2 <= (others => 0);
				
				p3		<= 0;     p2 	<= 0;   p1		<= 0;	

                tvalid <= (others => '0');
                tlast <= (others => '0');
--                tuser <= (others => (others => '0'));
                tkeep <= (others => (others => '0'));
			elsif en_conv = '1' then
				p9 		<= to_integer(unsigned(gray_tdata));      p8 	<= p9;    p7 	<= p8;    row_buffer1 <= p7 & row_buffer1(0 to row_buffer1'length-2);
					
				p6 		<= row_buffer1(row_buffer1'length - 1);   p5 	<= p6;    p4 	<= p5;    row_buffer2 <= p4 & row_buffer2(0 to row_buffer2'length-2);
					
				p3		<= row_buffer2(row_buffer2'length - 1);   p2 	<= p3;    p1	<= p2;

                tvalid <= gray_tvalid & tvalid(0 to tvalid'length-2);
                tlast <= gray_tlast & tlast(0 to tlast'length-2);
--                tuser <= gray_tuser & tuser(0 to tuser'length-2);
                tkeep <= gray_tkeep & tkeep(0 to tkeep'length-2);
			end if;
		end if;
	end process;				

	-- wait until first pixel reaches the desired position
	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
			  pre_cnt <= 0;
			else
			  if gray_tvalid = '1' then
					if pre_cnt < image_width + 2 then-- less than length + 2
						pre_cnt	<= pre_cnt + 1;
					else 
						pre_cnt	<= pre_cnt;
					end if;
			  else
			         pre_cnt <= pre_cnt;
			  end if;
			end if;    
		end if;
	end process;


	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
			  row <= 0;
			  start_conv <= '0';
			elsif col = image_width and row = image_height -1 then
		      row <= 0;
		    elsif col = image_width and row < image_height -1 then
			  row <= row + 1; 
    		else
				row <= row;
		    end if;
	   end if;
	end process;

	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
			     col <= 0;
			     start_conv <= '0';
			elsif pre_cnt = image_width + 2 and gray_tvalid = '1' and col = image_width then
				 col <= 0;  
				 start_conv <= '1';
		    elsif pre_cnt = image_width + 2 and gray_tvalid = '1' and col < image_width then
				 col <= col + 1;
				 start_conv <= '1';
    	    else
			     col <= col;
			     start_conv <= '1';
		   end if;
	   end if;
	end process;

	conv_stage2: process(aclk_out)
	begin
		if rising_edge(aclk_out) then
		   if aresetn_out = '0' then
				wx9 <= 0; 	wx8 <= 0;  	wx7 <= 0;
				wx6 <= 0; 	wx5 <= 0; 	wx4 <= 0;
				wx3 <= 0; 	wx2 <= 0; 	wx1 <= 0;
													
				wy9 <= 0; 	wy8 <= 0;  	wy7 <= 0;
				wy6 <= 0; 	wy5 <= 0; 	wy4 <= 0;
				wy3 <= 0; 	wy2 <= 0; 	wy1 <= 0;  	    
					
				stage1 <= '0';   
				tvalid1 <= '0';
				tlast1 <= '0';
--				tuser1 <= (others => '0');
				tkeep1   <= (others => '0');
			elsif pre_cnt = image_width + 2 and gray_tvalid = '1' then 
				stage1 <= '1';
				tvalid1 <= tvalid(tvalid'length -1);
				tlast1 <= tlast(tlast'length -1);
--				tuser1 <= tuser(tuser'length -1);
				tkeep1 <= tkeep(tkeep'length -1);
--	row_loop:for row in 0 to image_height -1 loop
--	   col_loop:for col in 0 to image_width -1 loop
				if row = 0 then
					if col = 0 then
						wx9 <= p9*m9; 	wx8 <= p8*m8;  	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= 0*m3; 	wx2 <= 0*m2; 	wx1 <= 0*m1;
									
						wy9 <= p9*k9; 	wy8 <= p8*k8;  	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= 0*k3; 	wy2 <= 0*k2; 	wy1 <= 0*k1;                        		
						
					elsif col = image_width -1 then
						wx9 <= 0*m9;  	wx8 <= p8*m8;  	wx7 <= p7*m7;
						wx6 <= 0*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= 0*m3; 	wx2 <= 0*m2; 	wx1 <= 0*m1;
									
						wy9 <= 0*k9;  	wy8 <= p8*k8;  	wy7 <= p7*k7;
						wy6 <= 0*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= 0*k3; 	wy2 <= 0*k2; 	wy1 <= 0*k1;   
						
					else
						wx9 <= p9*m9;  	wx8 <= p8*m8;  	wx7 <= p7*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= 0*m3; 	wx2 <= 0*m2; 	wx1 <= 0*m1;
									
						wy9 <= p9*k9;  	wy8 <= p8*k8;  	wy7 <= p7*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= 0*k3; 	wy2 <= 0*k2; 	wy1 <= 0*k1;
						
					end if;
					
				elsif row = image_height - 1 then
					if col = 0 then
					
						wx9 <= 0*m9; 	wx8 <= 0*m8; 	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= p3*m3;  	wx2 <= p2*m2;  	wx1 <= 0*m1;
									
						wy9 <= 0*m9; 	wy8 <= 0*k8; 	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= p3*k3;  	wy2 <= p2*k2;  	wy1 <= 0*k1;                   
										
					elsif col = image_width -1 then
						wx9 <= 0*m9; 	wx8 <= 0*m8; 	wx7 <= 0*m7;
						wx6 <= 0*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= 0*m3; 	wx2 <= p2*m2;  	wx1 <= p1*m1;
									
						wy9 <= 0*k9; 	wy8 <= 0*k8; 	wy7 <= 0*k7;
						wy6 <= 0*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= 0*k3; 	wy2 <= p2*k2;  	wy1 <= p1*k1;
				
					else
						wx9 <= 0*m9; 	wx8 <= 0*m8; 	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= p3*m3;  	wx2 <= p2*m2;  	wx1 <= p1*m1;
									
						wy9 <= 0*k9; 	wy8 <= 0*k8; 	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= p3*k3;  	wy2 <= p2*k2;  	wy1 <= p1*k1;
						
					end if;   
				else
					if col = 0 then
						wx9 <= p9*m9; 	wx8 <= p8*m8; 	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= p3*m3; 	wx2 <= p2*m2; 	wx1 <= 0*m1;
									
						wy9 <= p9*k9; 	wy8 <= p8*k8; 	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= p3*k3; 	wy2 <= p2*k2; 	wy1 <= 0*k1;
							
					elsif col = image_width -1 then
						wx9 <= 0*m9; 	wx8 <= p8*m8; 	wx7 <= p7*m7;
						wx6 <= 0*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= 0*m3; 	wx2 <= p2*m2; 	wx1 <= p1*m1;
									
						wy9 <= 0*k9; 	wy8 <= p8*k8; 	wy7 <= p7*k7;
						wy6 <= 0*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= 0*m3; 	wy2 <= p2*k2; 	wy1 <= p1*k1;
						
					else
						wx9 <= p9*m9; 	wx8 <= p8*m8; 	wx7 <= p7*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
						wx3 <= p3*m3; 	wx2 <= p2*m2; 	wx1 <= p1*m1;
										
						wy9 <= p9*k9; 	wy8 <= p8*k8; 	wy7 <= p7*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
						wy3 <= p3*k3; 	wy2 <= p2*k2; 	wy1 <= p1*k1;
							   
					end if;  
				end if;
--			end loop col_loop;	
--			end loop row_loop;
		   end if;
		end if;
	end process;

	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
				stage2 	<= '0';
				sumx 		<= 0;
				sumy 		<= 0;
				tvalid2     <= '0';
				tlast2      <= '0';
--				tuser2      <= (others => '0');
				tkeep2   <= (others => '0');
			elsif stage1 = '1' then
				sumx 		<= wx1+wx2+wx3+wx4+wx5+wx6+wx7+wx8+wx9;
				sumy 		<= wy1+wy2+wy3+wy4+wy5+wy6+wy7+wy8+wy9;
				
				stage2 	<= '1';
				
				tvalid2 <= tvalid1;
				tlast2  <= tlast1;
--				tuser2  <= tuser1;
				tkeep2   <= tkeep1;
			end if;
		end if;
	end process;

	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
		   if aresetn_out = '0' then
				sum 	<= 0;
				tvalid3     <= '0';
				tlast3      <= '0';
--				tuser3      <= (others => '0');		
				tkeep3   <= (others => '0');		
		   elsif stage2 = '1' then
				sum 	<= abs(sumx) + abs(sumy);
			
				tvalid3 <= tvalid2;
				tlast3  <= tlast2;
--				tuser3  <= tuser2;
				tkeep3   <= tkeep2;				
		   end if;
		end if;
	end process;


	conv_tdata 		<= 	(others => '1') when sum > 255 else
						(others => '0') when sum < 125 else
						(others => '1');
	
--	conv_tdata(31 downto 24)       <= (others => '0');
--	conv_tdata(23 downto 16)       <= std_logic_vector(to_unsigned(sum,8));
--	conv_tdata(15 downto 8)       <= std_logic_vector(to_unsigned(sum,8));
--	conv_tdata(7 downto 0)       <= std_logic_vector(to_unsigned(sum,8));
	
	conv_tvalid 	<= tvalid3;
	conv_tlast 		<= tlast3;
--	conv_tuser 		<= tuser3;
    conv_tkeep      <= tkeep3;
    
	gray_tready     <= conv_tready;
		
end architecture conv;

-- Name			: Shoukath Ali Mohammad
-- Title		: convolution
-- Description 	: apply convolution on the streaming image pixel data

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity convolution is
	generic (
			data_width 		: integer;
			image_width 	: integer;
			image_height	: integer
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;
			
			en_conv			: in  std_logic;			
			
			gray_tvalid 	: in  std_logic;
			gray_tlast 		: in  std_logic;
			gray_tuser 		: in  std_logic_vector(0 downto 0);
			gray_tdata 		: in  std_logic_vector(data_width/3-1 downto 0);

			aclk_out		: in  std_logic;
			aresetn_out		: in  std_logic;
			
			initiate_axis 	: out std_logic;
			
			conv_tready 	: in  std_logic;
			conv_tvalid 	: out std_logic;
			conv_tlast 		: out std_logic;
			conv_tuser 		: out std_logic_vector(0 downto 0);
			conv_tdata 		: out std_logic_vector(data_width-1 downto 0)
			
	);
end entity convolution;

architecture conv of convolution is 

component ASYN_FIFO_SGNL is
	generic (
			FIFO_DEPTH		: integer := 6
	);
	port ( 
			clk_in			: in  STD_LOGIC;
			rst_in			: in  STD_LOGIC;
			wr_en			: in  STD_LOGIC;
			data_in			: in  STD_LOGIC;
			
			clk_out 		: in  STD_LOGIC;
			rst_out 		: in  STD_LOGIC;
			rd_en			: in  STD_LOGIC;
			data_out		: out std_logic
	);
end component ASYN_FIFO_SGNL;

component ASYN_FIFO is
	generic (
			DATA_WIDTH  	: integer := 24;
			FIFO_DEPTH		: integer := 6
	);
	port ( 
			clk_in			: in  STD_LOGIC;
			rst_in			: in  STD_LOGIC;
			wr_en			: in  STD_LOGIC;
			data_in			: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
			
			clk_out 		: in  STD_LOGIC;
			rst_out 		: in  STD_LOGIC;
			rd_en			: in  STD_LOGIC;
			data_out		: out std_logic_VECTOR(DATA_WIDTH-1 downto 0)
	);
end component ASYN_FIFO;

	constant wait_time		: integer := 32; -- standard wait time for axis 
	signal 	start_delay 	: std_logic_vector(5 downto 0);

	signal start_cnt, ready	: std_logic;
    signal stage1, stage2, stage3 : std_logic;
    
	type line_buffer is array (0 to image_width -4) of integer;
	signal 	row_buffer1 	: line_buffer := (others => 0);
	signal  row_buffer2 	: line_buffer := (others => 0);

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

	constant fifo_depth 	: integer := image_width + image_width/2;
	signal fifo_rd, fifo_wr : std_logic;
	
	signal data_final       : std_logic_VECTOR(DATA_WIDTH-1 downto 0);
	signal tlast, start     : std_logic;
	signal tuser            : std_logic_vector(gray_tuser'length -1 downto 0);
	signal tdata            : std_logic_vector(data_width-1 downto 0);
begin

-- load fifo with valid signal when en_conv in on to later control output to next stage

	tvalid_FIFO: ASYN_FIFO_SGNL
		generic map (
			FIFO_DEPTH 	=> fifo_depth
		)
		port map (
			clk_in		=> aclk_in,
			rst_in		=> aresetn_in,
			wr_en		=> ready,
			data_in		=> gray_tvalid,
			
			clk_out 	=> aclk_out,
			rst_out 	=> aresetn_out,
			rd_en		=> fifo_rd,
			data_out	=> tvalid_ctl	
		);

	--  load fifo with all axis signals. output when tvalid_ctl
	tlast_FIFO: ASYN_FIFO_SGNL
		generic map (
			FIFO_DEPTH 	=> fifo_depth
		)
		port map (
			clk_in		=> aclk_in,
			rst_in		=> aresetn_in,
			wr_en		=> gray_tvalid,
			data_in		=> gray_tlast,
			
			clk_out 	=> aclk_out,
			rst_out 	=> aresetn_out,
			rd_en		=> tvalid_ctl,
			data_out	=> tlast	
		);
		
	tuser_FIFO: ASYN_FIFO
		generic map (
			data_width  => gray_tuser'length,
			FIFO_DEPTH 	=> fifo_depth
		)
		port map (
			clk_in		=> aclk_in,
			rst_in		=> aresetn_in,
			wr_en		=> gray_tvalid,
			data_in		=> gray_tuser,
			
			clk_out 	=> aclk_out,
			rst_out 	=> aresetn_out,
			rd_en		=> tvalid_ctl,
			data_out	=> tuser	
		);


	conv_data_FIFO: ASYN_FIFO
		generic map (
			data_width  => data_width,
			FIFO_DEPTH 	=> 50
		)
		port map (
			clk_in		=> aclk_out,
			rst_in		=> aresetn_out,
			wr_en		=> fifo_wr,
			data_in		=> data_final,
			
			clk_out 	=> aclk_out,
			rst_out 	=> aresetn_out,
			rd_en		=> tvalid_ctl,
			data_out	=> tdata	
		);
	
-- wait for ready = '1' to initiate all registers with zeros
	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
				start_delay <= (others => '0');
				ready 		<= '0';
			elsif start_delay = std_logic_vector(to_unsigned(wait_time,6)) then
				ready 		<= '1';
			elsif start_delay < std_logic_vector(to_unsigned(wait_time,6)) then
				start_delay <= std_logic_vector(unsigned(start_delay) + 1);
				ready 		<= '0';
			end if;
		end if;
	end process;

		initiate_axis <= ready;

	-- buffer data when gray_tvalid
	conv_stage1: process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
				p9 			<= 0;
				p8 			<= 0;
				p7 			<= 0;
				row_buffer1 <= (others => 0);
				row_buffer2 <= (others => 0);
				p6 			<= 0;
				p5 			<= 0;
				p4 			<= 0;
				p3			<= 0;
				p2 			<= 0;
				p1			<= 0;	
				start_cnt   <= '0';	
			elsif gray_tvalid = '1' and ready = '1' then
				p9 			<= to_integer(unsigned(gray_tdata));
				p8 			<= p9;
				p7 			<= p8;
				
				row_buffer1 <= p7 & row_buffer1(0 to row_buffer1'length-2);
					
				p6 			<= row_buffer1(row_buffer1'length - 1);
				p5 			<= p6;
				p4 			<= p5;
					
				row_buffer2 <= p4 & row_buffer2(0 to row_buffer2'length-2);
					
				p3			<= row_buffer2(row_buffer2'length - 1);
				p2 			<= p3;
				p1			<= p2;
					
				start_cnt <= '1';
			else    
				start_cnt <= '0';
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
			  if gray_tvalid = '1' and ready = '1' then
					if pre_cnt < image_width + 2 then-- less than length + 2
						pre_cnt	<= pre_cnt + 1;
					else 
						pre_cnt	<= image_width + 2;
					end if;
			   end if;
			end if;    
		end if;
	end process;


	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
			if aresetn_out = '0' then
			  row <= 0;
			  col <= 0;
			elsif start_cnt = '1' then
				if  pre_cnt = image_width + 2 then
					start 	<= '1';
					if col = image_width then
						if row = image_height -1 then 
							row <= 0;
						else 
							row <= row + 1;
						end if;    
						col <= 1;
					else
						col <= col + 1;
					end if;
				end if;
			else
				row <= row;
				col <= col;
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
			elsif start = '1' then
				if row = 0 then
					stage1 <= '1';
					if col = 1 then
						wx9 <= p9*m9; 	wx8 <= p8*m8;  	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= 0*m3; 	wx2 <= 0*m2; 	wx1 <= 0*m1;
									
						wy9 <= p9*k9; 	wy8 <= p8*k8;  	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= 0*k3; 	wy2 <= 0*k2; 	wy1 <= 0*k1;                        		
						
					elsif col = image_width then
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
					if col = 1 then
					
						wx9 <= 0*m9; 	wx8 <= 0*m8; 	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= p3*m3;  	wx2 <= p2*m2;  	wx1 <= 0*m1;
									
						wy9 <= 0*m9; 	wy8 <= 0*k8; 	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= p3*k3;  	wy2 <= p2*k2;  	wy1 <= 0*k1;                   
										
					elsif col = image_width then
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
					if col = 1 then
						wx9 <= p9*m9; 	wx8 <= p8*m8; 	wx7 <= 0*m7;
						wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= 0*m4;
						wx3 <= p3*m3; 	wx2 <= p2*m2; 	wx1 <= 0*m1;
									
						wy9 <= p9*k9; 	wy8 <= p8*k8; 	wy7 <= 0*k7;
						wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= 0*k4;
						wy3 <= p3*k3; 	wy2 <= p2*k2; 	wy1 <= 0*k1;
							
					elsif col = image_width then
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
		   else 
			stage1 <= '0';
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
			elsif stage1 = '1' then
				sumx 		<= wx1+wx2+wx3+wx4+wx5+wx6+wx7+wx8+wx9;
				sumy 		<= wy1+wy2+wy3+wy4+wy5+wy6+wy7+wy8+wy9;
				stage2 	<= '1';
			else 
				stage2 	<= '0';
			end if;
		end if;
	end process;

	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
		   if aresetn_out = '0' then
				sum 	<= 0;
				fifo_wr <= '0';
		   elsif stage2 = '1' then
				sum 	<= abs(sumx) + abs(sumy);
				fifo_wr <= '1';
		   else 
				fifo_wr <= '0';
		   end if;
		end if;
	end process;

	process(aclk_out)
	begin
		if rising_edge(aclk_out) then
		   if aresetn_out = '0' then
				fifo_rd <= '0';
		   elsif fifo_wr = '1' then
				fifo_rd <= '1';
		   else 
				fifo_rd <= '0';
		   end if;
		end if;
	end process;
	

	data_final 		<= 	(others => '1') when sum > 255 else
						(others => '0') when sum < 125 else
						(others => '1');
	
	conv_tvalid 	<= '1' 	 when tvalid_ctl = '1' else '0';
	conv_tlast 		<= tlast when tvalid_ctl = '1' and conv_tready = '1' else '0';
	conv_tuser 		<= tuser when tvalid_ctl = '1' and conv_tready = '1' else (others => '0');
	conv_tdata 		<= tdata when tvalid_ctl = '1' and conv_tready = '1' else (others => '0');
			
end architecture conv;
-- Name			: Shoukath Ali Mohammad
-- Title		: convolution
-- Description 	: apply 3x3 sobel gx and gy convolution on the streaming image pixel data

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity intensity_gradient is
	generic (
			data_width 		: integer := 32;
			image_width 	: integer := 640;
			image_height	: integer := 400
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;			
			
			gauss_tvalid 	: in  std_logic;
			gauss_tlast 	: in  std_logic;
			gauss_tdata 	: in  std_logic_vector(data_width -1 downto 0);
            gauss_tready    : out std_logic;
            gauss_tkeep     : in std_logic_vector(data_width/8 -1 downto 0);
			
			conv_tready 	: in  std_logic;
			conv_tvalid 	: out std_logic;
			conv_tlast 		: out std_logic;
			conv_tkeep      : out std_logic_vector(data_width/8 -1 downto 0);
			conv_tdata 		: out std_logic_vector(data_width -1 downto 0)
			
	);
end entity intensity_gradient;

architecture conv of intensity_gradient is 

	type line_buffer is array (0 to image_width -4) of integer;
	signal 	row_buffer1 	: line_buffer;
	signal  row_buffer2 	: line_buffer;

    type axis_tvalid_buffer is array (0 to image_width -1) of std_logic;
	signal 	tvalid 	: axis_tvalid_buffer;
	signal 	tlast 	: axis_tvalid_buffer;
	
	signal tvalid1, tvalid2, tvalid3, tvalid4, tvalid5, tvalid6, tvalid7, tvalid_1, tvalid_2 : std_logic;
	signal tlast1, tlast2, tlast3, tlast4, tlast5, tlast6, tlast7, tlast_1, tlast_2 : std_logic;
	
	signal 	p9, p8, p7 		: integer;
	signal 	p6, p5, p4 		: integer;
	signal 	p3, p2, p1 		: integer;

	signal 	wx9, wx8, wx7 	: integer;
	signal 	wx6, wx5, wx4 	: integer;
	signal 	wx3, wx2, wx1 	: integer;

	signal 	wy9, wy8, wy7 	: integer;
	signal 	wy6, wy5, wy4 	: integer;
	signal 	wy3, wy2, wy1 	: integer;
	

    signal sumx, sumy, sum, sumgx, sumgy  : integer;
	signal row, col    : integer; 

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

    
begin
	


	-- buffer data
	pipeline: process(aclk_in)
	begin
		if rising_edge(aclk_in) then
			if aresetn_in = '0' then
				p9 		<= 0;     p8 	<= 0;   p7 		<= 0;     row_buffer1 <= (others => 0);
				
				p6 		<= 0;     p5 	<= 0;   p4 		<= 0;     row_buffer2 <= (others => 0);
				
				p3		<= 0;     p2 	<= 0;   p1		<= 0;	

                tvalid  <= (others => '0');     tvalid_1 <= '0';  tvalid_2 <= '0';
                tlast   <= (others => '0');     tlast_1  <= '0';  tlast_2  <= '0';
			elsif conv_tready = '1' then
				p9 		<= to_integer(unsigned(gauss_tdata(7 downto 0)));      p8 	<= p9;    p7 	<= p8;    row_buffer1 <= p7 & row_buffer1(0 to row_buffer1'length-2);
					
				p6 		<= row_buffer1(row_buffer1'length - 1);   			   p5 	<= p6;    p4 	<= p5;    row_buffer2 <= p4 & row_buffer2(0 to row_buffer2'length-2);
					
				p3		<= row_buffer2(row_buffer2'length - 1);   			   p2 	<= p3;    p1	<= p2;

                tvalid  <= gauss_tvalid & tvalid(0 to tvalid'length-2); 
                tvalid_1<= tvalid(tvalid'length -1);  						   tvalid_2 <= tvalid_1;
                
                tlast   <= gauss_tlast & tlast(0 to tlast'length-2); 
                tlast_1 <= tlast(tlast'length -1);     						   tlast_2 <= tlast_1;
			end if;
		end if;
	end process;				

	row_col: process(aclk_in)	
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
		      row <= 0;
			  col <= 0;
		   elsif conv_tready = '1' then
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

	conv: process(aclk_in)
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
				wx9 <= 0; 	wx8 <= 0;  	wx7 <= 0;
				wx6 <= 0; 	wx5 <= 0; 	wx4 <= 0;
				wx3 <= 0; 	wx2 <= 0; 	wx1 <= 0;
													
				wy9 <= 0; 	wy8 <= 0;  	wy7 <= 0;
				wy6 <= 0; 	wy5 <= 0; 	wy4 <= 0;
				wy3 <= 0; 	wy2 <= 0; 	wy1 <= 0;  	    
					 
				tvalid1 <= '0';
				tlast1 <= '0';
			elsif conv_tready = '1' then 
				tvalid1 <= tvalid_2;
				tlast1 <= tlast_2;
			     if  tvalid_2 = '1' then
                    if row = 0 then
                        if col = 0 then
                            wx9 <= p9*m9; 	wx8 <= p8*m8;  	wx7 <= p8*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p5*m4;
                            wx3 <= p6*m3; 	wx2 <= p5*m2; 	wx1 <= p5*m1;
                                        
                            wy9 <= p9*k9; 	wy8 <= p8*k8;  	wy7 <= p8*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p5*k4;
                            wy3 <= p6*k3; 	wy2 <= p5*k2; 	wy1 <= p5*k1;                        		
                            
                        elsif col = image_width -1 then
                            wx9 <= p8*m9;  	wx8 <= p8*m8;  	wx7 <= p7*m7;
                            wx6 <= p5*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p5*m3; 	wx2 <= p5*m2; 	wx1 <= p4*m1;
                                        
                            wy9 <= p8*k9;  	wy8 <= p8*k8;  	wy7 <= p7*k7;
                            wy6 <= p5*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p5*k3; 	wy2 <= p5*k2; 	wy1 <= p4*k1;   
                            
                        else
                            wx9 <= p9*m9;  	wx8 <= p8*m8;  	wx7 <= p7*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p6*m3; 	wx2 <= p5*m2; 	wx1 <= p4*m1;
                                        
                            wy9 <= p9*k9;  	wy8 <= p8*k8;  	wy7 <= p7*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p6*k3; 	wy2 <= p5*k2; 	wy1 <= p4*k1;
                            
                        end if;
                        
                    elsif row = image_height - 1 then
                        if col = 0 then
                        
                            wx9 <= p6*m9; 	wx8 <= p5*m8; 	wx7 <= p5*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p5*m4;
                            wx3 <= p3*m3;  	wx2 <= p2*m2;  	wx1 <= p2*m1;
                                        
                            wy9 <= p6*m9; 	wy8 <= p5*k8; 	wy7 <= p5*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p5*k4;
                            wy3 <= p3*k3;  	wy2 <= p2*k2;  	wy1 <= p2*k1;                   
                                            
                        elsif col = image_width -1 then
                            wx9 <= p5*m9; 	wx8 <= p5*m8; 	wx7 <= p4*m7;
                            wx6 <= p5*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p2*m3; 	wx2 <= p2*m2;  	wx1 <= p1*m1;
                                        
                            wy9 <= p5*k9; 	wy8 <= p5*k8; 	wy7 <= p4*k7;
                            wy6 <= p5*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p2*k3; 	wy2 <= p2*k2;  	wy1 <= p1*k1;
                    
                        else
                            wx9 <= p6*m9; 	wx8 <= p5*m8; 	wx7 <= p4*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p3*m3;  	wx2 <= p2*m2;  	wx1 <= p1*m1;
                                        
                            wy9 <= p6*k9; 	wy8 <= p5*k8; 	wy7 <= p4*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p3*k3;  	wy2 <= p2*k2;  	wy1 <= p1*k1;
                            
                        end if;   
                    else
                        if col = 0 then
                            wx9 <= p9*m9; 	wx8 <= p8*m8; 	wx7 <= p8*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p5*m4;
                            wx3 <= p3*m3; 	wx2 <= p2*m2; 	wx1 <= p2*m1;
                                        
                            wy9 <= p9*k9; 	wy8 <= p8*k8; 	wy7 <= p8*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p5*k4;
                            wy3 <= p3*k3; 	wy2 <= p2*k2; 	wy1 <= p2*k1;
                                
                        elsif col = image_width -1 then
                            wx9 <= p8*m9; 	wx8 <= p8*m8; 	wx7 <= p7*m7;
                            wx6 <= p5*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p2*m3; 	wx2 <= p2*m2; 	wx1 <= p1*m1;
                                        
                            wy9 <= p8*k9; 	wy8 <= p8*k8; 	wy7 <= p7*k7;
                            wy6 <= p5*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p2*m3; 	wy2 <= p2*k2; 	wy1 <= p1*k1;
                            
                        else
                            wx9 <= p9*m9; 	wx8 <= p8*m8; 	wx7 <= p7*m7;
                            wx6 <= p6*m6; 	wx5 <= p5*m5; 	wx4 <= p4*m4;
                            wx3 <= p3*m3; 	wx2 <= p2*m2; 	wx1 <= p1*m1;
                                            
                            wy9 <= p9*k9; 	wy8 <= p8*k8; 	wy7 <= p7*k7;
                            wy6 <= p6*k6; 	wy5 <= p5*k5; 	wy4 <= p4*k4;
                            wy3 <= p3*k3; 	wy2 <= p2*k2; 	wy1 <= p1*k1;
                                   
                        end if;  
                    end if;
                end if;
		   end if;
		end if;
	end process;

gx_gy_calc:process(aclk_in)
	begin
		if rising_edge(aclk_in) then
	       if aresetn_in = '0' then
				sumx    <= 0;
				sumy    <= 0;
				tvalid2 <= '0';
				tlast2  <= '0';
		   elsif conv_tready = '1' then
				sumx 	<= wx1+wx2+wx3+wx4+wx5+wx6+wx7+wx8+wx9;
				sumy 	<= wy1+wy2+wy3+wy4+wy5+wy6+wy7+wy8+wy9;
				tvalid2 <= tvalid1;
				tlast2  <= tlast1;
		   end if;
		end if;
	end process;

gradient_cal:process(aclk_in)
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
				sum 	<= 0;
				tvalid3 <= '0';
				tlast3  <= '0';	
				sumgx 		<= 0;
				sumgy 		<= 0;
		   elsif conv_tready = '1' then
				sum 	<= abs(sumx) + abs(sumy);
				tvalid3 <= tvalid2;
				tlast3  <= tlast2;
                sumgx <= sumx;
				sumgy <= sumy;
		   end if;
		end if;
	end process;

		
conv_tdata(7 downto   0)	<= 	(others => '1') when sum > 255 else
				            (others => '0') when sum < 0 else
				            std_logic_vector(to_unsigned(sum,8));   -- |gx|+|gy|
				            
conv_tdata(18 downto  8)    <= std_logic_vector(to_signed(sumgx,11)); -- gx
conv_tdata(29 downto 19)    <= std_logic_vector(to_signed(sumgy,11)); -- gy				
conv_tdata(31 downto 30)    <= (others => '0');	
	
conv_tvalid 	<= tvalid3;
conv_tlast 		<= tlast3;
conv_tkeep      <= (others => '1');
    
gauss_tready     <= conv_tready;
	
end architecture conv;
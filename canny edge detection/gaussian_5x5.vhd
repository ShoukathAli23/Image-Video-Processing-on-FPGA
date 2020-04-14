-- Name			: Shoukath Ali Mohammad
-- Title		: gaussian_filter 5x5
-- Description 	: apply gaussian filter of size 5x5 on the streaming image pixel data

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity gaussian_filter_5x5 is
	generic (
		data_width 		: integer := 32;
		image_width 	: integer := 640;
		image_height	: integer := 400
	);
	port (	
		aclk_in 		: in  std_logic;
		aresetn_in 		: in  std_logic;

		gray_tvalid 	: in  std_logic;
		gray_tlast 		: in  std_logic;
		gray_tdata 		: in  std_logic_vector(data_width -1 downto 0);
        gray_tready     : out std_logic;
        gray_tkeep      : in  std_logic_vector(data_width/8 -1 downto 0);

		gauss_tready 	: in  std_logic;
		gauss_tvalid 	: out std_logic;
		gauss_tlast 	: out std_logic;
		gauss_tkeep     : out  std_logic_vector(data_width/8 -1 downto 0);
		gauss_tdata 	: out std_logic_vector(data_width -1 downto 0)
		);
end entity gaussian_filter_5x5;


architecture gauss of gaussian_filter_5x5 is 
    
	type line_buffer is array (0 to image_width -6) of integer;
	signal 	row_buffer1 	: line_buffer := (others => 0);
	signal  row_buffer2 	: line_buffer := (others => 0);
	signal  row_buffer3 	: line_buffer := (others => 0);
	signal  row_buffer4 	: line_buffer := (others => 0);

    type axis_tvalid_buffer_a is array (0 to image_width -1) of std_logic;
    type axis_tvalid_buffer_b is array (0 to 2) of std_logic;
	signal 	tvalida 	: axis_tvalid_buffer_a := (others => '0');
	signal 	tvalidb 	: axis_tvalid_buffer_a := (others => '0');
	signal  tvalidc     : axis_tvalid_buffer_b := (others => '0');
		
	type axis_tlast_buffer_a is array (0 to image_width -1) of std_logic;
	type axis_tlast_buffer_b is array (0 to 2) of std_logic;
	signal 	tlasta 	: axis_tlast_buffer_a := (others => '0');
	signal 	tlastb 	: axis_tlast_buffer_a := (others => '0');
	signal 	tlastc 	: axis_tlast_buffer_b := (others => '0');
		
	signal tvalid1, tvalid2, tvalid3, tvalid4, tvalid5 : std_logic;
	signal tlast1, tlast2, tlast3, tlast4, tlast5 : std_logic;
	
	signal res : std_logic_vector(data_width -1 downto 0);
	
	signal 	p25, p24, p23, p22, p21    : integer;
	signal 	p20, p19, p18, p17, p16    : integer;
	signal 	p15, p14, p13, p12, p11    : integer;
	signal 	p10, p9 , p8 , p7 , p6 	   : integer;
	signal 	p5 , p4 , p3 , p2 , p1 	   : integer;

    signal 	w25, w24, w23, w22, w21    : integer;
    signal 	w20, w19, w18, w17, w16    : integer;
	signal 	w15, w14, w13, w12, w11    : integer;
	signal 	w10, w9 , w8 , w7 , w6 	   : integer;
	signal 	w5 , w4 , w3 , w2 , w1 	   : integer;

    signal sum1, sum2, sum3, sum4, sum5, sum  : integer;
    
	signal row, col : integer; 

	------- gaussian 5x5 Filter ----------------------------------------------------
	constant g25 : integer := 256;    constant g24 : integer := 1024;    constant g23 : integer := 1536;     constant g22 : integer := 1024;     constant g21 : integer := 256;    
	constant g20 : integer := 1024;   constant g19 : integer := 4096;    constant g18 : integer := 6144;     constant g17 : integer := 4096;     constant g16 : integer := 1024;
	constant g15 : integer := 1536;   constant g14 : integer := 6144;    constant g13 : integer := 9216;     constant g12 : integer := 6144;     constant g11 : integer := 1536;
	constant g10 : integer := 1024;   constant g9  : integer := 4096;    constant g8  : integer := 6144;     constant g7  : integer := 4096;     constant g6  : integer := 1024;
	constant g5  : integer := 256;    constant g4  : integer := 1024;    constant g3  : integer := 1536;     constant g2  : integer := 1024;     constant g1  : integer := 256;
	
	
	----           | 1  4  6   4  1 |
	----           | 4  16 24 16  4 |
	----     1/256*| 6  24 36 16  6 |    
	----           | 4  16 24 16  4 | 
	----           | 1  4  6   4  1 |
------- Filter ----------------------------------------------------

-- map 
--      g25 g24 g23 g22 g21     p25 p24 p23 p22 p21     row_buffer1 
--      g20 g19 g18 g17 g16     p20 p19 p18 p17 p16     row_buffer2
--      g15 g14 g13 g12 g11     p15 p14 p13 p12 p11     row_buffer3
--      g10 g9  g8  g7  g6      p10 p9  p8  p7  p6      row_buffer4
--      g5  g4  g3  g2  g1      p5  p4  p3  p2  p1

	
begin
	
	-- buffer data
	pypeline: process(aclk_in)
	begin
		if rising_edge(aclk_in) then
			if aresetn_in = '0' then
			
				p25 <= 0; p24 <= 0; p23 <= 0; p22 <= 0; p21 <= 0; row_buffer1 <= (others => 0);
				p20 <= 0; p19 <= 0; p18 <= 0; p17 <= 0; p16 <= 0; row_buffer2 <= (others => 0);
				p15 <= 0; p14 <= 0; p13 <= 0; p12 <= 0; p11 <= 0; row_buffer3 <= (others => 0);
				p10 <= 0; p9  <= 0; p8  <= 0; p7  <= 0; p8  <= 0; row_buffer4 <= (others => 0);
				p5  <= 0; p4  <= 0; p3  <= 0; p2  <= 0; p1  <= 0; 

                tvalida <= (others => '0');
                tvalidb <= (others => '0');
                tvalidc <= (others => '0');
                
                tlasta <= (others => '0');
                tlastb <= (others => '0');
                tlastc <= (others => '0');
                
			elsif gauss_tready = '1' then

                tvalida <= gray_tvalid & tvalida(0 to tvalida'length-2);
                tvalidb <= tvalida(tvalida'length -1) & tvalidb(0 to tvalidb'length-2);
                tvalidc <= tvalidb(tvalidb'length -1) & tvalidc(0 to tvalidc'length-2);
                
                tlasta <= gray_tlast & tlasta(0 to tlasta'length-2);
                tlastb <= tlasta(tlasta'length -1) & tlastb(0 to tlastb'length-2);
                tlastc <= tlastb(tlastb'length -1) & tlastc(0 to tlastc'length-2);

                p25 <= to_integer(unsigned(gray_tdata(7 downto 0)));    p24 <= p25; p23 <= p24; p22 <= p23; p21 <= p22; row_buffer1 <= p21 & row_buffer1(0 to row_buffer1'length-2);
				p20 <= row_buffer1(row_buffer1'length - 1); p19 <= p20; p18 <= p19; p17 <= p18; p16 <= p17; row_buffer2 <= p16 & row_buffer2(0 to row_buffer2'length-2);
				p15 <= row_buffer2(row_buffer2'length - 1); p14 <= p15; p13 <= p14; p12 <= p13; p11 <= p12; row_buffer3 <= p11 & row_buffer3(0 to row_buffer3'length-2);
				p10 <= row_buffer3(row_buffer3'length - 1); p9  <= p10; p8  <= p9;  p7  <= p8;  p6  <= p7;  row_buffer4 <= p6 & row_buffer4(0 to row_buffer4'length-2);
				p5  <= row_buffer4(row_buffer4'length - 1); p4  <= p5;  p3  <= p4;  p2  <= p3;  p1  <= p2; 
			
			end if;
		end if;
	end process;				

	row_col: process(aclk_in)
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
                col <= 0;
                row <= 0;
            elsif gauss_tready = '1' then
                if tvalidc(tvalidc'length -1) = '1' then 	
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
				w25 <= 0; 	w24 <= 0;  	w23 <= 0;   w22 <= 0;  	w21 <= 0; 
				w20 <= 0; 	w19 <= 0; 	w18 <= 0;   w17 <= 0; 	w16 <= 0;  
				w15 <= 0; 	w14 <= 0; 	w13 <= 0;   w12 <= 0; 	w11 <= 0;   
				w10 <= 0; 	w9  <= 0; 	w8  <= 0;   w7  <= 0; 	w6  <= 0;  
				w5  <= 0; 	w4  <= 0; 	w3  <= 0;   w2  <= 0; 	w1  <= 0;   
					
				tvalid1 <= '0';
				tlast1  <= '0';
			elsif gauss_tready = '1' then
				tvalid1 <= tvalidc(tvalidc'length -1);
				tlast1  <= tlastc(tlastc'length -1);
			 if tvalidc(tvalidc'length -1) = '1' then 	
				if row = 0 then
					if col = 0 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p23;  	w21 <= g21*p23; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p18; 	w16 <= g16*p18;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p13; 	w11 <= g11*p13;   
                        w10 <= g10*p15; 	w9  <= g9*p14; 	    w8  <= g8*p13;    w7  <= g7*p13;  	w6  <= g6*p13;  
                        w5  <= g5*p15; 	    w4  <= g4*p14;    	w3  <= g3*p13;    w2  <= g2*p13;  	w1  <= g1*p13;                    		
					elsif col = 1 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p15; 	w9  <= g9*p14; 	    w8  <= g8*p13;    w7  <= g7*p12;  	w6  <= g6*p12;  
                        w5  <= g5*p15; 	    w4  <= g4*p14;    	w3  <= g3*p13;    w2  <= g2*p12;  	w1  <= g1*p12;     
					elsif col = image_width-2 then
                        w25 <= g25*p24; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p19; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p14; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p14; 	w9  <= g9*p14; 	    w8  <= g8*p13;    w7  <= g7*p12;  	w6  <= g6*p11;  
                        w5  <= g5*p14; 	    w4  <= g4*p14;    	w3  <= g3*p13;    w2  <= g2*p12;  	w1  <= g1*p11;     
					elsif col = image_width-1 then
                        w25 <= g25*p23; 	w24 <= g24*p23;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p18; 	w19 <= g19*p18; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p13; 	w14 <= g14*p13; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p13; 	w9  <= g9*p13; 	    w8  <= g8*p13;    w7  <= g7*p12;  	w6  <= g6*p11;  
                        w5  <= g5*p13; 	    w4  <= g4*p13;    	w3  <= g3*p13;    w2  <= g2*p12;  	w1  <= g1*p11;     
					else
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p15; 	w9  <= g9*p14; 	    w8  <= g8*p13;    w7  <= g7*p12;  	w6  <= g6*p11;  
                        w5  <= g5*p15; 	    w4  <= g4*p14;    	w3  <= g3*p13;    w2  <= g2*p12;  	w1  <= g1*p11;     
					end if;
				elsif row = 1 then
					if col = 0 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p23;  	w21 <= g21*p23; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p18; 	w16 <= g16*p18;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p13; 	w11 <= g11*p13;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p8;  	w6  <= g6*p8;  
                        w5  <= g5*p10; 	    w4  <= g4*p9;    	w3  <= g3*p8;     w2  <= g2*p8;  	w1  <= g1*p8;                    		
					elsif col = 1 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p22; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p12;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p7;  
                        w5  <= g5*p10; 	    w4  <= g4*p9;    	w3  <= g3*p8;     w2  <= g2*p7;  	w1  <= g1*p7;     
					elsif col = image_width-2 then
                        w25 <= g25*p24; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p19; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p14; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p9; 	    w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p9; 	    w4  <= g4*p9;    	w3  <= g3*p8;      w2  <= g2*p7;  	w1  <= g1*p6;     
					elsif col = image_width-1 then
                        w25 <= g25*p23; 	w24 <= g24*p23;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p18; 	w19 <= g19*p18; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p13; 	w14 <= g14*p13; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p8; 	    w9  <= g9*p8; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p8; 	    w4  <= g4*p8;    	w3  <= g3*p8;     w2  <= g2*p7;  	w1  <= g1*p6;     
					else
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p10; 	    w4  <= g4*p9;    	w3  <= g3*p8;      w2  <= g2*p7;  	w1  <= g1*p6;     
					end if;
				elsif row = image_height-2 then
					if col = 0 then
                        w25 <= g25*p20; 	w24 <= g24*p19;  	w23 <= g23*p18;   w22 <= g22*p18;  	w21 <= g21*p18; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p18; 	w16 <= g16*p18;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p13; 	w11 <= g11*p13;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p8;  	w6  <= g6*p8;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p3;  	w1  <= g1*p3;                    		
					elsif col = 1 then
                        w25 <= g25*p20; 	w24 <= g24*p19;  	w23 <= g23*p18;   w22 <= g22*p17;  	w21 <= g21*p17; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p17;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p12;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p7;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p2;     
					elsif col = image_width-2 then
                        w25 <= g25*p19; 	w24 <= g24*p19;   	w23 <= g23*p18;   w22 <= g22*p17;  	w21 <= g21*p16; 
                        w20 <= g20*p19; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p14; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p9; 	    w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p4; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					elsif col = image_width-1 then
                        w25 <= g25*p18; 	w24 <= g24*p18;  	w23 <= g23*p18;   w22 <= g22*p17;  	w21 <= g21*p16; 
                        w20 <= g20*p18; 	w19 <= g19*p18; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p13; 	w14 <= g14*p13; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p8; 	    w9  <= g9*p8; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p3; 	    w4  <= g4*p3;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					else
                        w25 <= g25*p20; 	w24 <= g24*p19;   	w23 <= g23*p18;   w22 <= g22*p17;  	w21 <= g21*16; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					end if;
				elsif row = image_height-1 then
					if col = 0 then
                        w25 <= g25*p15; 	w24 <= g24*p14;  	w23 <= g23*p13;   w22 <= g22*p13;  	w21 <= g21*p13; 
                        w20 <= g20*p15;   	w19 <= g19*p14;   	w18 <= g18*p13;   w17 <= g17*p13; 	w16 <= g16*p13;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p13; 	w11 <= g11*p13;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p8;  	w6  <= g6*p8;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p3;  	w1  <= g1*p3;                    		
					elsif col = 1 then
                        w25 <= g25*p15; 	w24 <= g24*p14;  	w23 <= g23*p13;   w22 <= g22*p12;  	w21 <= g21*p12; 
                        w20 <= g20*p15;   	w19 <= g19*p14;   	w18 <= g18*p13;   w17 <= g17*p12; 	w16 <= g16*p12; 
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p12;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p7;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p2;     
					elsif col = image_width-2 then
                        w25 <= g25*p14; 	w24 <= g24*p14;   	w23 <= g23*p13;   w22 <= g22*p12;  	w21 <= g21*p11; 
                        w20 <= g20*p14;   	w19 <= g19*p14;   	w18 <= g18*p13;   w17 <= g17*p12; 	w16 <= g16*p11;  
                        w15 <= g15*p14; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p9; 	    w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p4; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					elsif col = image_width-1 then
                        w25 <= g25*p13; 	w24 <= g24*p13;  	w23 <= g23*p13;   w22 <= g22*p12;  	w21 <= g21*p11; 
                        w20 <= g20*p13;   	w19 <= g19*p13;   	w18 <= g18*p13;   w17 <= g17*p12; 	w16 <= g16*p11;  
                        w15 <= g15*p13; 	w14 <= g14*p13; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p8; 	    w9  <= g9*p8; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p3; 	    w4  <= g4*p3;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					else
                        w25 <= g25*p15; 	w24 <= g24*p14;   	w23 <= g23*p13;   w22 <= g22*p12;  	w21 <= g21*p11; 
                        w20 <= g20*p15;   	w19 <= g19*p14;   	w18 <= g18*p13;   w17 <= g17*p12; 	w16 <= g16*p11; 
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					end if;								
				else 
					if col = 0 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p23;  	w21 <= g21*p23; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p18; 	w16 <= g16*p18;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p13; 	w11 <= g11*p13;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p8;  	w6  <= g6*p8;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p3;  	w1  <= g1*p3;                    		
					elsif col = 1 then
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p22; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p17;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p12;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p7;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;      w2  <= g2*p2;  	w1  <= g1*p2;     
					elsif col = image_width-2 then
                        w25 <= g25*p24; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p19; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p14; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p9; 	    w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p4; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					elsif col = image_width-1 then
                        w25 <= g25*p23; 	w24 <= g24*p23;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p18; 	w19 <= g19*p18; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p13; 	w14 <= g14*p13; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p8; 	    w9  <= g9*p8; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p3; 	    w4  <= g4*p3;    	w3  <= g3*p3;      w2  <= g2*p2;  	w1  <= g1*p1;     
					else
                        w25 <= g25*p25; 	w24 <= g24*p24;  	w23 <= g23*p23;   w22 <= g22*p22;  	w21 <= g21*p21; 
                        w20 <= g20*p20; 	w19 <= g19*p19; 	w18 <= g18*p18;   w17 <= g17*p17; 	w16 <= g16*p16;  
                        w15 <= g15*p15; 	w14 <= g14*p14; 	w13 <= g13*p13;   w12 <= g12*p12; 	w11 <= g11*p11;   
                        w10 <= g10*p10; 	w9  <= g9*p9; 	    w8  <= g8*p8;     w7  <= g7*p7;  	w6  <= g6*p6;  
                        w5  <= g5*p5; 	    w4  <= g4*p4;    	w3  <= g3*p3;     w2  <= g2*p2;  	w1  <= g1*p1;     
					end if;	
				end if;	
                
             end if;							
		   end if;
		end if;
	end process;

	process(aclk_in)
	begin
		if rising_edge(aclk_in) then
			if aresetn_in = '0' then
				sum1    <= 0;
				sum2    <= 0;
				sum3    <= 0;
				sum4    <= 0;
				sum5    <= 0;
				tvalid2 <= '0';
				tlast2  <= '0';
			elsif gauss_tready = '1' then
				sum1 	<= w1+w2+w3+w4+w5;
				sum2    <= w6+w7+w8+w9+w10;
				sum3    <= w11+w12+w13+w14+w15;
				sum4    <= w16+w17+w18+w19+w20;
				sum5    <= w21+w22+w23+w24+w25;
				tvalid2 <= tvalid1;
				tlast2  <= tlast1;
			end if;
		end if;
	end process;

	process(aclk_in)
	begin
		if rising_edge(aclk_in) then
			if aresetn_in = '0' then
				sum 	<= 0;
				tvalid3 <= '0';
				tlast3  <= '0';
			elsif gauss_tready = '1' then
				sum 	<= sum1 + sum2 + sum3 + sum4 + sum5;
				tvalid3 <= tvalid2;
				tlast3  <= tlast2;
			end if;
		end if;
	end process;
	
	process(aclk_in)
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
				res 	<= (others => '0');
				tvalid4 <= '0';
				tlast4  <= '0';
		   elsif gauss_tready = '1' then
                res 	<= std_logic_vector(to_unsigned(sum,32));
				tvalid4 <= tvalid3;
				tlast4  <= tlast3;	
		   end if;
		end if;
	end process;

	
	gauss_tdata(7 downto   0) <= res(23 downto 16);
	gauss_tdata(15 downto  8) <= res(23 downto 16);
	gauss_tdata(23 downto 16) <= res(23 downto 16);
	gauss_tdata(31 downto 24) <= (others => '0');
	
	gauss_tvalid 	<= tvalid4;
	gauss_tlast 	<= tlast4;
    gauss_tkeep     <= (others => '0');
    
	gray_tready     <= gauss_tready;

end architecture gauss;
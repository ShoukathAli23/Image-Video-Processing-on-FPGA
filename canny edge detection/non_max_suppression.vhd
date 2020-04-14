-- Name			: Shoukath Ali Mohammad
-- Title		: non_max_suppression
-- Description 	: apply non max suppression 

library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;


entity non_max_suppression is
	generic (
			data_width 		: integer := 32;
			image_width 	: integer := 640;
			image_height	: integer := 400
	);
	port (	
			aclk_in 		: in  std_logic;
			aresetn_in 		: in  std_logic;		
			
			conv_tvalid 	: in  std_logic;
			conv_tlast 		: in  std_logic;
			conv_tdata 		: in  std_logic_vector(data_width -1 downto 0);
            conv_tready     : out std_logic;
            conv_tkeep      : in std_logic_vector(data_width/8 -1 downto 0);

			non_max_tready 	: in  std_logic;
			non_max_tvalid 	: out std_logic;
			non_max_tlast 	: out std_logic;
			non_max_tkeep   : out std_logic_vector(data_width/8 -1 downto 0);
			non_max_tdata 	: out std_logic_vector(data_width -1 downto 0)
			
	);
end entity non_max_suppression;

architecture conv of non_max_suppression is 

 	type line_buffer is array (0 to image_width -4) of integer;
	signal 	row_buffer1 	: line_buffer;
	signal  row_buffer2 	: line_buffer;

 	type theta_buffer is array (0 to image_width -1) of integer;
 	signal  theta_buff      : theta_buffer;

    type axis_tvalid_buffer is array (0 to image_width -1) of std_logic;
	signal 	tvalid 	: axis_tvalid_buffer;
	signal 	tlast 	: axis_tvalid_buffer;
	
	signal tvalid1, tvalid2, tvalid3, tvalid4, tvalid5, tvalid6, tvalid7, tvalid_1, tvalid_2 : std_logic;
	signal tlast1, tlast2, tlast3, tlast4, tlast5, tlast6, tlast7, tlast_1, tlast_2 : std_logic;
	signal theta1, theta2 : integer;
	
	signal 	p9, p8, p7 : integer;
	signal 	p6, p5, p4 : integer;
	signal 	p3, p2, p1 : integer;


    
    signal pre_value, post_value, center_value, valid_data : integer;
	signal row, col    : integer; 

    constant arctan_0   : integer := 0; --unsigned(7 downto 0) := "00000000";
    constant arctan_45  : integer := 45; --unsigned(7 downto 0) := "00101101";
    constant arctan_90  : integer := 90; --unsigned(7 downto 0) := "01011010";
    constant arctan_135 : integer := 135; --unsigned(7 downto 0) := "10000111";
    constant max        : integer := 255;
    constant min        : integer := 0;
begin
	


	-- buffer data
	conv_stage1: process(aclk_in)
	begin
		if rising_edge(aclk_in) then
			if aresetn_in = '0' then
				p9 		<= 0;     p8 	<= 0;   p7 		<= 0;     row_buffer1 <= (others => 0);
				
				p6 		<= 0;     p5 	<= 0;   p4 		<= 0;     row_buffer2 <= (others => 0);
				
				p3		<= 0;     p2 	<= 0;   p1		<= 0;	
                theta_buff <= (others => 0);
                theta1 <= 0; theta2 <= 0;
                tvalid <= (others => '0');  tvalid_1 <= '0'; tvalid_2 <= '0';
                tlast  <= (others => '0');  tlast_1  <= '0'; tlast_2  <= '0';
			elsif non_max_tready = '1' then
				p9 		<= to_integer(unsigned(conv_tdata(7 downto 0)));      p8 	<= p9;    p7 	<= p8;    row_buffer1 <= p7 & row_buffer1(0 to row_buffer1'length-2);
					
				p6 		<= row_buffer1(row_buffer1'length - 1);   p5 	<= p6;    p4 	<= p5;    row_buffer2 <= p4 & row_buffer2(0 to row_buffer2'length-2);
					
				p3		<= row_buffer2(row_buffer2'length - 1);   p2 	<= p3;    p1	<= p2;

                theta_buff <= to_integer(unsigned(conv_tdata(15 downto 8))) & theta_buff(0 to theta_buff'length-2);
                theta1 <= theta_buff(theta_buff'length -1); theta2 <= theta1;
                
                tvalid <= conv_tvalid & tvalid(0 to tvalid'length-2); 
                tvalid_1 <= tvalid(tvalid'length -1); tvalid_2 <= tvalid_1;
                
                tlast <= conv_tlast & tlast(0 to tlast'length-2); 
                tlast_1<= tlast(tlast'length -1); tlast_2 <= tlast_1;

			end if;
		end if;
	end process;				

	row_col: process(aclk_in)	
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
		      row <= 0;
			  col <= 0;
		   elsif non_max_tready = '1' then
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

process(aclk_in)
	begin
		if rising_edge(aclk_in) then
		   if aresetn_in = '0' then
                pre_value   <= 0;
                post_value  <= 0;					 
				tvalid1     <= '0';
				tlast1      <= '0';
			elsif non_max_tready = '1' then 
				tvalid1     <= tvalid_2;
				tlast1      <= tlast_2;
			     if  tvalid_2 = '1' then
			        center_value     <= p5;
                    if row = 0 then
                        if col = 0 then
                            if arctan_0 = theta2 then
                                pre_value  <= max;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= max;
                                post_value <= max;
                            elsif arctan_90 = theta2 then
                                pre_value  <= max;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= max;
                                post_value <= p9;                                                        
                            end if;              		
    
                        elsif col = image_width -1 then 
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= max;
                            elsif arctan_45 = theta2 then
                                pre_value  <= max;
                                post_value <= p7;
                            elsif arctan_90 = theta2 then
                                pre_value  <= max;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= max;
                                post_value <= max;                                                        
                            end if;                              
                        else
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= max;
                                post_value <= p7;
                            elsif arctan_90 = theta2 then
                                pre_value  <= max;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= max;
                                post_value <= p9;                                                        
                            end if;                              
                        end if;
                        
                    elsif row = image_height - 1 then
                        if col = 0 then               
                            if arctan_0 = theta2 then
                                pre_value  <= max;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= p3;
                                post_value <= max;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= max;
                            elsif arctan_135 = theta2 then
                                pre_value  <= max;
                                post_value <= max;                                                        
                            end if;                                              
                        elsif col = image_width -1 then
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= max;
                            elsif arctan_45 = theta2 then
                                pre_value  <= max;
                                post_value <= max;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= max;
                            elsif arctan_135 = theta2 then
                                pre_value  <= p1;
                                post_value <= max;                                                        
                            end if;                      
                        else
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= p3;
                                post_value <= max;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= max;
                            elsif arctan_135 = theta2 then
                                pre_value  <= p1;
                                post_value <= max;                                                        
                            end if;                              
                        end if;   
                    else
                        if col = 0 then
                            if arctan_0 = theta2 then
                                pre_value  <= max;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= p3;
                                post_value <= max;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= max;
                                post_value <= p9;                                                        
                            end if;                                  
                        elsif col = image_width -1 then
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= max;
                            elsif arctan_45 = theta2 then
                                pre_value  <= max;
                                post_value <= p7;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= p1;
                                post_value <= max;                                                        
                            end if;                              
                        else
                            if arctan_0 = theta2 then
                                pre_value  <= p4;
                                post_value <= p6;
                            elsif arctan_45 = theta2 then
                                pre_value  <= p3;
                                post_value <= p7;
                            elsif arctan_90 = theta2 then
                                pre_value  <= p2;
                                post_value <= p8;
                            elsif arctan_135 = theta2 then
                                pre_value  <= p1;
                                post_value <= p9;                                                        
                            end if;                                     
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
                valid_data <= 0;
                tvalid2 <= '0';
                tlast2  <= '0'; 
			elsif non_max_tready = '1' then 
			    tvalid2 <= tvalid1;
			    tlast2 <= tlast1;
			     if center_value >= pre_value and center_value >= post_value then -- only if the center pexel is greater than or equal to pre pixel  
			         valid_data <= center_value;                                  -- and post pixel allow it to pass through else set it to zero
			     else 
			         valid_data <= min;
			     end if;
			end if;
	   end if;
    end process;
		
	non_max_tdata(7 downto 0)      <= std_logic_vector(to_unsigned(valid_data,8));
	non_max_tdata(15 downto 8)     <= std_logic_vector(to_unsigned(valid_data,8));
	non_max_tdata(23 downto 16)    <= std_logic_vector(to_unsigned(valid_data,8));
	non_max_tdata(31 downto 24)    <= (others => '0');
	
	non_max_tvalid 	   <= tvalid2;
	non_max_tlast 	   <= tlast2;
    non_max_tkeep      <= (others => '1');
    
	conv_tready        <= non_max_tready;
	
end architecture conv;
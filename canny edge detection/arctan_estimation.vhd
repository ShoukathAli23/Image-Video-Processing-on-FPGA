-- Name			: Shoukath Ali Mohammad
-- Title		: theta
-- Description 	: estimate arctan(gy/gx)

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity theta is
	generic (
			data_width 		     : integer := 32
	);
	port (	
			aclk                 : in  std_logic;
			aresetn              : in  std_logic;			
			
			conv_tvalid_in 	     : in  std_logic;
			conv_tlast_in 		 : in  std_logic;
			conv_tdata_in 		 : in  std_logic_vector(data_width -1 downto 0);
            conv_tready_in       : out std_logic;
            conv_tkeep_in        : in std_logic_vector(data_width/8 -1 downto 0);
			
			conv_tready_out 	 : in  std_logic;
			conv_tvalid_out 	 : out std_logic;
			conv_tlast_out 		 : out std_logic;
			conv_tkeep_out       : out std_logic_vector(data_width/8 -1 downto 0);
			conv_tdata_out 		 : out std_logic_vector(data_width -1 downto 0);

--- connections to division ip provided by xilinx 
			
            DIVISOR_tdata        : out STD_LOGIC_VECTOR ( 15 downto 0 );
            DIVISOR_tvalid       : out STD_LOGIC;
            DIVIDEND_tdata       : out STD_LOGIC_VECTOR ( 15 downto 0 );
            DIVIDEND_tvalid      : out STD_LOGIC;           
            
            quotient_tdata       : in STD_LOGIC_VECTOR ( 23 downto 0 );
            quotient_tuser       : in STD_LOGIC_VECTOR ( 0 to 0 );
            quotient_tvalid      : in STD_LOGIC			
                    
	);
end theta;

architecture Behavioral of theta is

	type div_data_buffer is array (0 to 20) of unsigned(7 downto 0);
	signal 	data_wait_for_quotient 	: div_data_buffer;

	type div_tvalid_buffer is array (0 to 20) of std_logic;
	signal 	tvalid_wait_for_quotient 	: div_tvalid_buffer;
	signal 	tlast_wait_for_quotient 	: div_tvalid_buffer;	
    signal  negative_quotient           : div_tvalid_buffer;

	signal tvalid1, tvalid2, tvalid3, tvalid4, tvalid5, tvalid6, tvalid7, tvalid_1, tvalid_2 : std_logic;
	signal tlast1, tlast2, tlast3, tlast4, tlast5, tlast6, tlast7, tlast_1, tlast_2 : std_logic;
		
	signal dividend, divisor : std_logic_vector(15 downto 0);
	signal dividend_valid, divisor_valid, quotient_valid : std_logic;
	signal quotient_with_fraction : std_logic_vector(23 downto 0);
	signal negative_x, negative_y, negative_y_by_x, negative_y_by_x1 : std_logic;
	
	constant tan_0    : std_logic_vector(9 downto 0) := "0000000000";
    constant tan_22_5 : std_logic_vector(9 downto 0) := "0001101001";
    constant tan_67_5 : std_logic_vector(9 downto 0) := "1001101001";
    
    signal theta : std_logic_vector(7 downto 0);
    signal quotient_reg : std_logic_vector(9 downto 0);
    
    signal sumx, sumy : integer;
    signal sum, gradient, gradient1, gradient2 : unsigned(7 downto 0);

begin


    sumx <= to_integer(signed(conv_tdata_in(18 downto 8))); -- gx
    sumy <= to_integer(signed(conv_tdata_in(29 downto 19))); -- gy
    sum  <= unsigned(conv_tdata_in(7 downto 0)); -- |gx|+|gy|

divisor_gen:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                divisor         <= (others => '0');
                divisor_valid   <= '0';
                negative_x      <= '0';
		   elsif conv_tready_out = '1' then
				divisor(10 downto 0)    <= std_logic_vector(to_unsigned(abs(sumx),11));
				divisor(15 downto 11)   <= (others => '0');
				divisor_valid           <= conv_tvalid_in;	
					   
				if sumx < 0 then -- check if gx is negative
				    negative_x  <= '1';
				else  
				    negative_x  <= '0';
				end if;
		   
		   end if;
		end if;
	end process;
	
dividend_gen:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                dividend        <= (others => '0');
                dividend_valid  <= '0';
                negative_y      <= '0';
		   elsif conv_tready_out = '1' then
				dividend(10 downto 0)   <= std_logic_vector(to_unsigned(abs(sumy),11));
				dividend(15 downto 11)  <= (others => '0');
				dividend_valid          <= conv_tvalid_in;
				
				if sumy < 0 then -- check if gy is negative
				    negative_y <= '1';
				else  
				    negative_y <= '0';
				end if;	
		   
		   end if;
		end if;
	end process;

sign_of_quotient:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                gradient        <= (others => '0');
                tvalid4         <= '0';
                tlast4          <= '0';
                negative_y_by_x <= '0';
		   elsif conv_tready_out = '1' then
				negative_y_by_x <= negative_x xor negative_y; -- apply sign of quotient 
				gradient        <= sum;
				tvalid4         <= conv_tvalid_in;
				tlast4          <= conv_tlast_in;
		   end if;
		end if;
	end process;
		
wait_for_quotient:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                data_wait_for_quotient      <= (others => (others => '0'));
                tvalid_wait_for_quotient    <= (others => '0');
                tlast_wait_for_quotient     <= (others => '0');
                negative_quotient           <= (others => '0');
		   elsif conv_tready_out = '1' then
                data_wait_for_quotient      <= gradient & data_wait_for_quotient(0 to data_wait_for_quotient'length-2);
                tvalid_wait_for_quotient    <= tvalid4 & tvalid_wait_for_quotient(0 to tvalid_wait_for_quotient'length-2);
                tlast_wait_for_quotient     <= tlast4 & tlast_wait_for_quotient(0 to tlast_wait_for_quotient'length-2);
                negative_quotient           <= negative_y_by_x & negative_quotient(0 to negative_quotient'length-2);
		   end if;
		end if;
	end process;
	
check_div_by_zero:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                quotient_reg     <= (others => '0');
                tvalid5          <= '0';
                tlast5           <= '0';
                negative_y_by_x1 <= '0';
                gradient1 <= (others => '0');
		   elsif conv_tready_out = '1' then
                if quotient_valid = '1' then
                    if  quotient_with_fraction = x"FFFFFF" then -- condition for division by zero
                        quotient_reg <= (others => '0');
                    else 
                        quotient_reg <= quotient_with_fraction(9 downto 0);
                    end if;
                end if;
                tvalid5          <= tvalid_wait_for_quotient(tvalid_wait_for_quotient'length -1);
                tlast5           <= tlast_wait_for_quotient(tlast_wait_for_quotient'length -1);
                negative_y_by_x1 <= negative_quotient(negative_quotient'length -1);
                gradient1        <= data_wait_for_quotient(data_wait_for_quotient'length -1);
		   end if;
		end if;
	end process;

theta_estimation:process(aclk)
	begin
		if rising_edge(aclk) then
		   if aresetn = '0' then
                theta       <= (others => '0');
                tvalid6     <= '0';
                tlast6      <= '0';
                gradient2   <= (others => '0');
		   elsif conv_tready_out = '1' then
                if tan_0 <= quotient_reg and quotient_reg < tan_22_5 then -- if q is negative or positive theta = 0
                    theta <= std_logic_vector(to_unsigned(0, theta'length));
                elsif tan_22_5 <= quotient_reg and quotient_reg < tan_67_5 then 
                    if negative_y_by_x1 = '1' then                        -- if q is negative theta = 135  
                        theta <= std_logic_vector(to_unsigned(135, theta'length));
                    else                                                  -- if q is positive theta = 45 
                        theta <= std_logic_vector(to_unsigned(45, theta'length));
                    end if;
                elsif tan_67_5 <= quotient_reg then                       -- if q is negative or positive theta = 90
                        theta <= std_logic_vector(to_unsigned(90, theta'length));
                end if;
                tvalid6     <= tvalid5;
                tlast6      <= tlast5;
                gradient2   <= gradient1;
		   end if;
		end if;
	end process;

    conv_tready_in  <= conv_tready_out;
    
    conv_tdata_out(7 downto   0) <= std_logic_vector(gradient2);
    conv_tdata_out(15 downto  8) <= theta; -- pass theta to nect stage
    conv_tdata_out(31 downto 16) <= (others => '0');
    
    conv_tvalid_out <= tvalid6;
    conv_tkeep_out  <= (others => '1');
    conv_tlast_out  <= tlast6;

    DIVIDEND_tdata  <= dividend;
    DIVIDEND_tvalid <= dividend_valid;
    
    DIVISOR_tdata   <= divisor;
    DIVISOR_tvalid  <= divisor_valid;

    quotient_with_fraction <= quotient_tdata;
    quotient_valid <= quotient_tvalid;
    
    
end Behavioral;

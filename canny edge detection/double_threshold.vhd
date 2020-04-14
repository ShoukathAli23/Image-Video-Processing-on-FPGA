-- Name			: Shoukath Ali Mohammad
-- Title		: double_threshold
-- Description 	: apply upper and lower limit to stremaing pixel data

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity double_threshold is
	generic (
			data_width 		: integer := 32;
			lower_threshold : integer := 125;
			upper_threshold : integer := 255
	);
	port (	
			aclk 		    : in  std_logic;
			aresetn 		: in  std_logic;			
			
			non_max_tvalid 	: in  std_logic;
			non_max_tlast 	: in  std_logic;
			non_max_tdata 	: in  std_logic_vector(data_width -1 downto 0);
            non_max_tready  : out std_logic;
            non_max_tkeep   : in std_logic_vector(data_width/8 -1 downto 0);
			
			dTh_tready 	    : in  std_logic;
			dTh_tvalid 	    : out std_logic;
			dTh_tlast 		: out std_logic;
			dTh_tkeep       : out std_logic_vector(data_width/8 -1 downto 0);
			dTh_tdata 		: out std_logic_vector(data_width -1 downto 0)
	);
end double_threshold;

architecture Behavioral of double_threshold is
	signal	tvalid 	:  std_logic;
	signal	tlast 	:  std_logic;
	signal	tkeep   : std_logic_vector(data_width/8 -1 downto 0);
	signal	tdata   : std_logic_vector(data_width -1 downto 0);
	
	signal  data    : integer;
begin

data    <= to_integer(unsigned(non_max_tdata(7 downto 0)));

process(aclk)
begin
if rising_edge(aclk) then
    if aresetn = '0' then
        tvalid <= '0';
        tlast  <= '0';
        tkeep  <= (others => '0');
     else 
        if dTH_tready = '1' then
            tvalid <= non_max_tvalid;
            tlast  <= non_max_tlast;
            tkeep  <= non_max_tkeep;
        end if;
      end if;
end if;
end process;

process(aclk)
begin
if rising_edge(aclk) then
    if aresetn = '0' then
        tdata   <= (others => '0');
     else 
        if dTH_tready = '1' then
            if data >= lower_threshold  and data <= upper_threshold then
                tdata   <= non_max_tdata;
            elsif data < lower_threshold then
                tdata   <= (others => '0');
            elsif data > upper_threshold then
                tdata(23 downto 0)  <= (others => '1');
                tdata(31 downto 24) <= (others => '0');
            end if;
        end if;
      end if;
end if;
end process;
            
non_max_tready <= dTh_tready;

dTh_tvalid <= tvalid;
dTh_tlast  <= tlast;
dTh_tkeep  <= tkeep;
dTh_tdata  <= tdata;

end Behavioral;

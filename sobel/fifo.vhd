-- Name			: Shoukath Ali Mohammad
-- Title		: convolution
-- Description 	: asynchronous FIFO for data type std_logic_vector


library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity ASYN_FIFO is
	Generic (
		DATA_WIDTH  : integer := 24;
		FIFO_DEPTH	: integer := 6
	);
	Port ( 
		clk_in	: in  STD_LOGIC;
		rst_in	: in  STD_LOGIC;
		wr_en	: in  STD_LOGIC;
		data_in	: in  STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		
		clk_out : in  STD_LOGIC;
		rst_out : in  STD_LOGIC;
		rd_en	: in STD_LOGIC;
		data_out: out std_logic_VECTOR(DATA_WIDTH-1 downto 0)
	);
end entity ASYN_FIFO;

architecture FIFO of ASYN_FIFO is

type FIFO_Memory is array (0 to FIFO_DEPTH - 1) of STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
signal Memory : FIFO_Memory := (others => (others =>'0'));
		
signal Head : integer range 0 to FIFO_DEPTH - 1;
signal Tail : integer range 0 to FIFO_DEPTH - 1;
		
begin
	-- Memory Pointer Process
	fifo_read : process (clk_out)		
	begin
		if rising_edge(clk_out) then
			if rst_out = '0' then
				Tail <= 0;
			else
				if (rd_en = '1') then
						-- Update data output
						data_out <= Memory(Tail);
						
						-- Update Tail pointer as needed
						if (Tail = FIFO_DEPTH - 1) then
							Tail <= 0;
						else
							Tail <= Tail + 1;
						end if;
				else 
				    data_out <= (others => '0');
				end if;
			end if;
		end if;
	end process;

	fifo_write : process (clk_in)		
	begin
		if rising_edge(clk_in) then
			if rst_out = '0' then
				Head <= 0;
				Memory <= (others => (others =>'0'));
			else	
				if (wr_en = '1') then
						-- Write Data to Memory
						Memory(Head) <= data_in;
						
						-- Increment Head pointer as needed
						if (Head = FIFO_DEPTH - 1) then
							Head <= 0;
						else
							Head <= Head + 1;
						end if;
				end if;
				
			end if;
		end if;
	end process;
				
end architecture FIFO;
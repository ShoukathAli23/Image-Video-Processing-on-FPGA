library IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity STD_FIFO_SGNL is
	Generic (
		constant DATA_WIDTH  : integer := 1;
		constant FIFO_DEPTH	: integer := 6
	);
	Port ( 
		CLK		: in  STD_LOGIC;
		RST		: in  STD_LOGIC;
		WriteEn	: in  STD_LOGIC;
		DataIn	: in  STD_LOGIC;
		ReadEn	: in  STD_LOGIC;
		DataOut	: out STD_LOGIC
	);
end STD_FIFO_SGNL;

architecture Behavioral of STD_FIFO_SGNL is

type FIFO_Memory is array (0 to FIFO_DEPTH - 1) of STD_LOGIC;
signal Memory : FIFO_Memory := (others => '0');
		
signal Head : integer range 0 to FIFO_DEPTH - 1;
signal Tail : integer range 0 to FIFO_DEPTH - 1;
		
begin
	-- Memory Pointer Process
	fifo_read : process (CLK)		
	begin
		if rising_edge(CLK) then
			if RST = '0' then
				Tail <= 0;
			else
				if (ReadEn = '1')then
						-- Update data output
						DataOut <= Memory(Tail);
						
						-- Update Tail pointer as needed
						if (Tail = FIFO_DEPTH - 1) then
							Tail <= 0;
						else
							Tail <= Tail + 1;
						end if;
				else 
				DataOut <= '0';
				end if;
			end if;
		end if;
	end process;

	fifo_write : process (CLK)		
	begin
		if rising_edge(CLK) then
			if RST = '0' then
				Head <= 0;
			else	
				if (WriteEn = '1')then
						-- Write Data to Memory
						Memory(Head) <= DataIn;
						
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
				
end Behavioral;
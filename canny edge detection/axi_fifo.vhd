-- Name			: Jonas "https://vhdlwhiz.com/axi-fifo/"
-- Modified by  : Shoukath Ali Mohammad
-- Title		: axi_fifo
-- Description 	: controlles the communication between the image popeline and axi dma

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity axi_fifo is
  generic (
    ram_width           : natural := 32;
    ram_depth           : natural := 2048
  );
  port (
    stream_in_clk       : in std_logic;
    stream_in_rstn      : in std_logic;
     
    -- AXI input interface
    stream_in_tready    : out std_logic;
    stream_in_tvalid    : in std_logic;
    stream_in_tdata     : in std_logic_vector(ram_width - 1 downto 0);
    stream_in_tlast     : in std_logic;
    stream_in_tkeep     : in std_logic_vector(ram_width/8 -1 downto 0); 

    stream_out_clk      : in std_logic;
    stream_out_rstn     : in std_logic;
     
    -- AXI output interface
    stream_out_tready   : in std_logic;
    stream_out_tvalid   : out std_logic;
    stream_out_tdata    : out std_logic_vector(ram_width - 1 downto 0);
    stream_out_tlast    : out std_logic;
    stream_out_tkeep    : out std_logic_vector(ram_width/8 -1 downto 0) 

  );
end axi_fifo; 

architecture Behavioral of axi_fifo is

-- The FIFO is full when the RAM contains ram_depth - 1 elements
type ram_type is array (0 to ram_depth - 1) of std_logic_vector(stream_in_tdata'range);
signal ram      : ram_type;

type tlast_type is array (0 to ram_depth - 1) of std_logic;
signal tlast    : tlast_type;

type tkeep_type is array (0 to ram_depth - 1) of std_logic_vector(stream_in_tkeep'range);
signal tkeep    : tkeep_type;

-- Newest element at head, oldest element at tail
subtype index_type is natural range ram_type'range;
signal head     : index_type;
signal tail     : index_type;
signal count    : index_type;
signal count_p1 : index_type;

-- Internal versions of entity signals with mode "out"
signal in_ready_i   : std_logic;
signal out_valid_i  : std_logic;

-- True the clock cycle after a simultaneous read and write
signal read_while_write_p1 : std_logic;

function next_index(
  index     : index_type;
  ready     : std_logic;
  valid     : std_logic) return index_type is
begin
  if ready = '1' and valid = '1' then
    if index = index_type'high then
      return index_type'low;
    else
      return index + 1;
    end if;
  end if;
 
  return index;
end function;

procedure index_proc(
  signal clk    : in std_logic;
  signal rst    : in std_logic;
  signal index  : inout index_type;
  signal ready  : in std_logic;
  signal valid  : in std_logic) is
begin
    if rising_edge(clk) then
      if rst = '0' then
        index <= index_type'low;
      else
        index <= next_index(index, ready, valid);
      end if;
    end if;
end procedure;

begin

stream_in_tready    <= in_ready_i;
stream_out_tvalid   <= out_valid_i;

-- Update head index on write
PROC_HEAD : index_proc(stream_in_clk, stream_in_rstn, head, in_ready_i, stream_in_tvalid);
 
-- Update tail index on read
PROC_TAIL : index_proc(stream_out_clk, stream_out_rstn, tail, stream_out_tready, out_valid_i);

PROC_RAM_IN : process(stream_in_clk)
begin
  if rising_edge(stream_in_clk) then
    ram(head)   <= stream_in_tdata;
    tlast(head) <= stream_in_tlast;
    tkeep(head) <= stream_in_tkeep;
  end if;
end process;

PROC_RAM_OUT : process(stream_out_clk)
begin
  if rising_edge(stream_out_clk) then
    stream_out_tdata    <= ram(next_index(tail, stream_out_tready, out_valid_i));
    stream_out_tlast    <= tlast(next_index(tail, stream_out_tready, out_valid_i));
    stream_out_tkeep    <= tkeep(next_index(tail, stream_out_tready, out_valid_i));
  end if;
end process;

PROC_COUNT : process(head, tail)
begin
  if head < tail then
    count   <= head - tail + ram_depth;
  else
    count   <= head - tail;
  end if;
end process;

PROC_COUNT_P1 : process(stream_in_clk)
begin
  if rising_edge(stream_in_clk) then
    if stream_in_rstn = '0' then
      count_p1  <= 0;
    else
      count_p1  <= count;
    end if;
  end if;
end process;

PROC_IN_READY : process(count)
begin
  if count < ram_depth - 1 then
    in_ready_i  <= '1';
  else
    in_ready_i  <= '0';
  end if;
end process;

PROC_READ_WHILE_WRITE_P1: process(stream_in_clk)
begin
  if rising_edge(stream_in_clk) then
    if stream_in_rstn = '0' then
      read_while_write_p1 <= '0';
 
    else
      read_while_write_p1   <= '0';
      if in_ready_i = '1' and stream_in_tvalid = '1' and stream_out_tready = '1' and out_valid_i = '1' then
        read_while_write_p1 <= '1';
      end if;
    end if;
  end if;
end process;

PROC_OUT_VALID : process(count, count_p1, read_while_write_p1)
begin
  out_valid_i   <= '1';
 
  -- If the RAM is empty or was empty in the prev cycle
  if count = 0 or count_p1 = 0 then
    out_valid_i <= '0';
  end if;
 
  -- If simultaneous read and write when almost empty
  if count = 1 and read_while_write_p1 = '1' then
    out_valid_i <= '0';
  end if;
 
end process;


end Behavioral;

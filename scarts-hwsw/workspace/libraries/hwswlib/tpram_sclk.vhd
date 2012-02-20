library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tpram_sclk is
	generic
	(
		ADDRLEN : integer range 2 to integer'high := 8;
		DATALEN	: integer range 2 to integer'high := 8
	);
	port 
	(	
		clk			: in std_logic;
		
		addr_a	: in std_logic_vector(ADDRLEN-1 downto 0);
		data_a	: in std_logic_vector(DATALEN-1 downto 0);
		we_a		: in std_logic := '0';
		q_a			: out std_logic_vector(DATALEN-1 downto 0);
		
		addr_b	: in std_logic_vector(ADDRLEN-1 downto 0);
		data_b	: in std_logic_vector(DATALEN-1 downto 0);
		we_b		: in std_logic := '0';
		q_b			: out std_logic_vector(DATALEN-1 downto 0);
		
		addr_c	: in std_logic_vector(ADDRLEN-1 downto 0);
		q_c			: out std_logic_vector(DATALEN-1 downto 0)
	);
	
end tpram_sclk;

architecture rtl of tpram_sclk is
	
	-- Build a 2-D array type for the RAM
	subtype word_t is std_logic_vector(DATALEN-1 downto 0);
	type memory_t is array(0 to (2**ADDRLEN)-1) of word_t;
	
	-- Declare the RAM
	signal ram : memory_t := (others => x"55");

begin
	
	-- Ports
	process(clk)
	begin
		if(rising_edge(clk)) then 
			if(we_a = '1') then
				ram(to_integer(unsigned(addr_a))) <= data_a;
			end if;

			if(we_b = '1') then
				ram(to_integer(unsigned(addr_b))) <= data_b;
			end if;

			q_a <= ram(to_integer(unsigned(addr_a)));
			q_b <= ram(to_integer(unsigned(addr_b)));
			q_c <= ram(to_integer(unsigned(addr_c)));
		end if;
	end process;
end rtl;

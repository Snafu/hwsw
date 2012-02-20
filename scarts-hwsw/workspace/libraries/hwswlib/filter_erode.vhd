library ieee;
use ieee.std_logic_1164.all;

library grlib;
use grlib.stdlib.all;

library work;
use work.hwswlib.all;


entity filter_erode is
	generic
	(
		ADDRLEN : integer range 2 to integer'high := 8;
		DATALEN	: integer range 2 to integer'high := 8
	);
	port 
	(
		rst			: in std_logic;
		clk			: in std_logic;
		
		pixeladdr				: out std_logic_vector(ADDRLEN-1 downto 0);
		pixeldata_post	: out std_logic_vector(DATALEN-1 downto 0);
		pixel_we				: out std_logic := '0';
		pixeldata_pre		: in std_logic_vector(DATALEN-1 downto 0)
	);
end entity;

architecture arch of filter_erode is
	signal pixeladdr_next, pixeladdr_old	: std_logic_vector(ADDRLEN-1 downto 0);
	signal pixeldata_post_next						: std_logic_vector(DATALEN-1 downto 0);
	signal pixel_we_next									: std_logic := '0';
begin

	dofilter: process(pixeldata_pre, pixeladdr_old)
	begin
		pixeladdr_next <= pixeladdr_old + '1';
		pixeldata_post_next <= pixeldata_pre;
		pixel_we_next <= '0';

		if pixeldata_pre = x"ba" then
			pixeldata_post_next <= x"be";
			pixel_we_next <= '1';
		end if;

	end process;


	reg: process(rst, clk)
	begin
		if rising_edge(clk) then
			pixeladdr <= pixeladdr_next;
			pixeladdr_old <= pixeladdr_next;
			pixeldata_post <= pixeldata_post_next;
			pixel_we <= pixel_we_next;
		end if;

		if rst = '0' then
			pixeladdr <= (others => '0');
			pixeldata_post <= (others => '0');
			pixel_we <= '0';
			pixeladdr_old <= (others => '0');
		end if;
	end process;

end architecture;

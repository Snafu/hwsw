library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--use work.scarts_pkg.all;

library work;
use work.i2clib.all;

entity i2cmaster_tb is

end i2cmaster_tb;

architecture sim of i2cmaster_tb is
	signal i2co_pin		: i2c_out_type;
	signal i2c_config_sel	: std_logic;
	signal clk         	: std_logic;
	signal rst         	: std_logic;
	signal exti		: module_in_type;
begin

	i2csim: i2cmaster
	port map
	(
		clk		=> clk,
		rst		=> rst,
		i2co		=> i2co_pin,
		extsel	=> i2c_config_sel,
		exti		=> exti
	);

	process
	begin
		clk <= '0';
		rst <= '0';
		wait for 10 ns;
		rst <= '1';

		loop 
			wait for 15ns;
			clk <= '1';       
			wait for 15ns;
			clk <= '0';
		end loop;

	end process;
	
	process
	begin
	  exti.data <= "00000000101010100011001100011101";
		i2c_config_sel <= '0';
		wait for 110ns;
		i2c_config_sel <= '1';
		wait for 10ns;
		i2c_config_sel <= '0';
		wait for 100000ns;
	end process;
end;

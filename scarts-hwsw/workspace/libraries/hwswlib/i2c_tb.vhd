library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;


--library grlib;
--use grlib.amba.all;

library work;
use work.i2clib.all;

entity i2cmaster_tb is

end i2cmaster_tb;

architecture sim of i2cmaster_tb is
	--signal i2ci_pin			:	i2c_in_type;
	signal i2co_pin			:	i2c_out_type;
	signal i2c_config_sel	:	std_logic;
	signal clk         : std_logic;
	signal rst         : std_logic;

begin

	i2csim: i2cmaster
	generic map
    (
	pindex	=> 2,
	paddr		=> 16#003#,
	pmask		=> 16#fff#,
	pirq		=> 0,
	oepol		=> 0
    )
	port map
    (
		clk	=>	clk,
		rst	=>	rst,
		--apbi	=>	apbi,
		--apbo	=>	apbo(2),
		--i2ci	=>	i2ci_pin,
		i2co	=>	i2co_pin,
		i2c_config_sel	=> i2c_config_sel
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
    i2c_config_sel <= '0';
	  wait for 110ns;
	  i2c_config_sel <= '1';
	  wait for 10ns;
	  i2c_config_sel <= '0';
	  wait for 100000ns;
end process;

end;

-----------------------------------------------------------------------------
-- Entity:      i2cmaster
-- File:        i2cmaster.vhd
-- Author:      Harald Glanzer
-- Modified:    
-- Contact:     harald.glanzer@gmail.com
-- Description: i2c master module
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.top_pkg.all;
use work.scarts_pkg.all;
use work.scarts_amba_pkg.all;
--use work.pkg_dis7seg.all;
--use work.pkg_counter.all;
--use work.ext_miniUART_pkg.all;

library grlib;
use grlib.amba.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.misc.all;
library hwswlib;
use work.hwswlib.all;


entity i2cmaster is
	generic(
		-- APB generics
		pindex  : integer := 0;                -- slave bus index
		paddr   : integer := 0;
		pmask   : integer := 16#fff#;
		pirq    : integer := 0;                -- interrupt index
		oepol   : integer range 0 to 1 := 0;   -- output enable polarity
		
		constant CAM_ADDRESS_RD		: integer := 16#BB#;		-- not used?
		constant CAM_ADDRESS_WR		: integer := 16#BA#;
		constant BUS_IDLE				: std_logic := '1');
	port (
		rst       : in std_logic;           -- Synchronous reset
		clk       : in std_logic;
		-- APB signals
		apbi  : in  apb_slv_in_type;
		apbo  : out apb_slv_out_type;

		-- I2C signals
		i2ci  : in  i2c_in_type;
		i2co  : out i2c_out_type;
		i2c_config_sel	:	in	std_logic);
end ;

architecture rtl of i2cmaster is

	type I2C_STATE_TYPE is (IDLE, SEND_STARTBIT, SEND_SLAVE_ADRESS, SEND_REGISTER_ADRESS, SEND_DATA_LOW, SEND_DATA_HIGH, SEND_FINISHED);
--	type I2C_BYTESTATE is (STARTBIT, B0, B1, B2, B3, B4, B5, B6, B7, STOPBIT);
	
	signal i2c_state				: I2C_STATE_TYPE;
	signal i2c_state_next		: I2C_STATE_TYPE;
	
	signal sda_sig			: std_logic;	
	signal sdc_sig			: std_logic;
	
	signal send_done		: std_logic;
	
	signal i2c_config_sel_old		 :	std_logic;
	signal i2c_config_sel_old_next :	std_logic;
	
	signal sdc_data		: std_logic_vector(7 downto 0);
	signal sdc_data_next	: std_logic_vector(7 downto 0);
	
	signal i2c_send_done			: std_logic;
	signal i2c_send_done_next	: std_logic;
	
	signal i2c_busy		: std_logic;	
	signal i2c_busy_next	: std_logic;
	
	signal sdc_counter		: integer range 0 to 5000;
	signal sdc_counter_next	: integer range 0 to 5000;

begin
	
	process(sdc_counter, sdc_counter_next)
	begin

		sdc_counter_next <= sdc_counter + 1;
		
		if(sdc_counter_next = 0)
		then
			sdc_sig <= '0';
		elsif(sdc_counter_next = 2000)
		then
			sdc_sig <= '1';
		elsif(sdc_counter_next = 4000)
		then
			sdc_counter_next <= 0;		
		end if;
	end process;

	process(sdc_sig)
	begin
		case i2c_state is
				when IDLE			=>
				
				when SEND_STARTBIT	=>
					
				when SEND_SLAVE_ADRESS	=>
				
				when SEND_REGISTER_ADRESS	=>
				
				when SEND_DATA_LOW	=>
			
				when SEND_DATA_HIGH	=>
					
				when SEND_FINISHED	=>
				
				end case;
	
	end process;
	
	process(i2c_state, i2c_busy, i2c_config_sel, i2c_config_sel_old, sdc_sig, i2c_send_done)
	begin
	
		i2c_config_sel_old_next <= i2c_config_sel;
		i2c_state_next <= i2c_state;
		i2c_send_done_next <= i2c_send_done;
						
		if(i2c_busy = '1')
		then
		
			case i2c_state is
				when IDLE			=>
					i2c_state_next <= SEND_STARTBIT;
				when SEND_STARTBIT	=>
					if(i2c_send_done /= i2c_send_done_next and i2c_send_done = '1')
					then
						i2c_state_next <= SEND_REGISTER_ADRESS;
					end if;
				when SEND_SLAVE_ADRESS	=>
					sdc_data_next <= "10111010";
					
					if(i2c_send_done /= i2c_send_done_next and i2c_send_done = '1')
					then
						i2c_state_next <= SEND_REGISTER_ADRESS;
					end if;
				when SEND_REGISTER_ADRESS	=>
					--sdc_data_next <= ''
					if(i2c_send_done /= i2c_send_done_next and i2c_send_done = '1')
					then
						i2c_state_next <= SEND_DATA_LOW;
					end if;
				when SEND_DATA_LOW	=>
					if(i2c_send_done /= i2c_send_done_next and i2c_send_done = '1')
					then
						i2c_state_next <= SEND_DATA_HIGH;
					end if;
				when SEND_DATA_HIGH	=>
					if(i2c_send_done /= i2c_send_done_next and i2c_send_done = '1')
					then
						i2c_state_next <= SEND_FINISHED;
					end if;
				when SEND_FINISHED	=>
				--i2c_state_next <= IDLE;
			
				end case;	
		else
			-- if no transfer is done at the moment and we get a proper flank, start statemachine
			if(i2c_config_sel_old /= i2c_config_sel and i2c_config_sel = '1')
			then
				i2c_busy_next <= '1';
			end if;
		end if;
	end process;
	
	
  process(clk, rst)
  begin
		if(rst = '0')
		then
			-- reset all values
			sda_sig <= '0';
			sdc_counter <= 0;
			i2co.sda <= BUS_IDLE;
			i2co.scl <= BUS_IDLE;
			i2c_state <= IDLE;
			i2c_busy <= '0';
			i2c_config_sel_old <= '0';
			i2c_send_done <= '0';
		else 
			-- set new values
			if(clk'event and clk = '1')
			then
				if(i2c_state = IDLE)
				then
					sdc_counter <= 0;
					i2co.sda <= BUS_IDLE;
					i2co.scl <= BUS_IDLE;
				else
					i2c_state <= i2c_state_next;
					i2co.sda <= sda_sig;
					i2co.scl <= sdc_sig;
					i2c_busy <= i2c_busy_next;
					
					i2c_send_done <= i2c_send_done_next;
					i2c_config_sel_old <= i2c_config_sel_old_next;
				end if;
			end if;
		end if;
		
	end process;
end;


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

use work.scarts_pkg.all;

library work;
use work.i2clib.all;

entity i2cmaster is
	generic(
		constant CAM_ADDRESS_RD	: std_logic_vector(7 downto 0) := "10111011";	-- 0xBB
		constant CAM_ADDRESS_WR	: std_logic_vector(7 downto 0) := "10111010";	-- 0xBA
		constant BUS_IDLE			: std_logic := '1');
	port (
		rst				: in std_logic;           -- Synchronous reset
		clk				: in std_logic;
		
		extsel			: in	std_logic;
		exti				: in  module_in_type;
		exto				: out module_out_type;
		
		-- I2C signals
		--i2ci			: in  i2c_in_type;
		i2co				: out i2c_out_type
		);
end;

architecture rtl of i2cmaster is

	-- SCARTS Extension
	subtype byte is std_logic_vector(7 downto 0);
	type register_set is array (0 to 3) of byte;

	constant STATUSREG_CUST : integer := 1;
	constant CONFIGREG_CUST : integer := 3;

	type reg_type is record
	  ifacereg		:	register_set;
	end record;

	signal r_next : reg_type;
	signal r : reg_type := 
	  (
	    ifacereg => (others => (others => '0'))
	  );
	signal rstint : std_ulogic;

	-- I2C Master
	type module_in_type is record
		reset     : std_ulogic;
		write_en  : std_ulogic;
		byte_en   : std_logic_vector(3 downto 0);
		data      : std_logic_vector(31 downto 0);
		addr      : std_logic_vector(14 downto 0);
	end record;

	type i2c_in_type is record
      scl : std_ulogic;
      sda : std_ulogic;
	end record;

	type i2c_out_type is record
      scl    : std_ulogic;
      scloen : std_ulogic;
      sda    : std_ulogic;
      sdaoen : std_ulogic;
      enable : std_ulogic;
	end record;

	--constant COUNTER_NEXTSTATE		:	integer	:=	0;
	--constant COUNTER_LOW				:	integer	:=	300;
	--constant	COUNTER_STARTSTOPBIT	:	integer	:=	400;
	--constant	COUNTER_RESET			:	integer	:=	500;
	
	constant COUNTER_NEXTSTATE		:	integer	:=	0;
	constant COUNTER_SETBIT 		:	integer	:= 50;		-- NOT USED YET
	constant COUNTER_LOW				:	integer	:=	124;
	constant	COUNTER_STARTSTOPBIT	:	integer	:=	190;
	constant	COUNTER_RESET			:	integer	:=	249;
	
	type I2C_STATE_TYPE is (IDLE, START_CLK, SEND_STARTBIT, SEND_SLAVE_ADRESS, SEND_REGISTER_ADRESS, SEND_DATA_LOW, SEND_DATA_HIGH, SEND_FINISHED, STOP_CLK);
	type I2C_BYTESTATE_TYPE is (IDLE, B0, B1, B2, B3, B4, B5, B6, B7, WAIT_ACK);
	
	signal i2c_state				: I2C_STATE_TYPE;
	signal i2c_state_next		: I2C_STATE_TYPE;
	
	signal i2c_bytestate			: I2C_BYTESTATE_TYPE;
	signal i2c_bytestate_next	: I2C_BYTESTATE_TYPE;
	
	signal sda_sig			: std_logic	:=	BUS_IDLE;	
	signal sdc_sig			: std_logic := BUS_IDLE;
	
	signal sda_data		: std_logic_vector(7 downto 0);
	signal sda_data_next	: std_logic_vector(7 downto 0);
	
	signal sdc_counter		: integer range 0 to 5010;
	signal sdc_counter_next	: integer range 0 to 5010;
	
	signal sda_buf				: std_ulogic;
	signal sda_buf_next		: std_ulogic;
	
	signal data_buffer		: std_logic_vector(23 downto 0);
	signal data_buffer_next	: std_logic_vector(23 downto 0);
		
begin
		
	process(clk, rst)
	begin
				
		if(rst = '0')
		then
			-- reset all values
			data_buffer <= "000000000000000000000000";
			
			sdc_counter <= 0;
			sda_data <= "00000000";
			sda_buf <= BUS_IDLE;
			
			i2co.sda <= BUS_IDLE;
			i2co.scl <= BUS_IDLE;
			i2c_state <= IDLE;
			i2c_bytestate <= IDLE;
      
			r.ifacereg <= (others => (others => '0'));
		else 
			-- set new values
			if(clk'event and clk = '1')
			then
				data_buffer <= data_buffer_next;
			
				sdc_counter <= sdc_counter_next;
				sda_data <= sda_data_next;
				sda_buf <= sda_buf_next;
				
				i2co.sda <= sda_sig;
				i2co.scl <= sdc_sig;
				i2c_state <= i2c_state_next;
				i2c_bytestate <= i2c_bytestate_next;
				
      	if rstint = RST_ACT then
        	r.ifacereg <= (others => (others => '0'));
      	else
      	  r <= r_next;
      	end if;
			end if;
		end if;
		
	end process;
	
	
	process(extsel, r, i2c_bytestate, i2c_state, sdc_counter, sda_data, sda_buf, sda_sig, data_buffer, exti)
    variable v : reg_type;
	begin
		v := r;
		
		-- used for buffering the 32bit word from APB
		-- which is only valid for a short time
		data_buffer_next <= data_buffer;
		
		sdc_sig <= BUS_IDLE;
		sda_sig <= sda_buf;
		
		-- this signals are NOT used
		i2co.scloen <= '0';
		i2co.sdaoen <= '0';
		i2co.enable <= '0';
	
		sdc_counter_next <= sdc_counter + 1;
		sda_data_next <= sda_data;

		i2c_state_next <= i2c_state;
		i2c_bytestate_next <= i2c_bytestate;
	
		if(i2c_state /= IDLE)
		then		
		if(sdc_counter < COUNTER_LOW)
			then
				sdc_sig <= '0';
				
			elsif(sdc_counter = COUNTER_STARTSTOPBIT)
			then
				if(i2c_state = SEND_STARTBIT)
				then
					sda_sig <= '0';
				end if;
				if(i2c_state = SEND_FINISHED )
				then
					sda_sig <= '1';
				end if;
			elsif(sdc_counter = COUNTER_RESET)
			then
				sdc_counter_next <= 0;
			end if;	
		else
			sdc_counter_next <= 0;
		end if;
	
	
		case i2c_bytestate is
			when IDLE		=>
				
			when B0			=>
				if(i2c_bytestate /= IDLE and sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(6);
					i2c_bytestate_next <= B1;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(7);
				end if;
				
			when B1			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(5);
					i2c_bytestate_next <= B2;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(6);
				end if;
				
			when B2			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(4);
					i2c_bytestate_next <= B3;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(5);
				end if;
				
			when B3			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(3);
					i2c_bytestate_next <= B4;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(4);
				end if;
				
			when B4			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(2);
					i2c_bytestate_next <= B5;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(3);
				end if;
				
			when B5			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(1);
					i2c_bytestate_next <= B6;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(2);
				end if;
				
			when B6			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= sda_data(0);
					i2c_bytestate_next <= B7;
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(1);
				end if;
				
			when B7			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_bytestate_next <= WAIT_ACK;
					--sda_sig <= 'Z';
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					sda_sig <= sda_data(0);
				end if;
				
			when WAIT_ACK	=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_bytestate_next <= IDLE;
					
					-- pull LOW so that STOPBIT can be sent
					
					--sda_sig <= '0';
				end if;
				
				if(sdc_counter = COUNTER_SETBIT)
				then
					if(i2c_state = SEND_FINISHED)
					then
						sda_sig <= '0';
					else
						sda_sig <= 'Z';
					end if;
				end if;
		end case;
					
		case i2c_state is
			when IDLE						=>
					
			when START_CLK					=> 
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_state_next <= SEND_STARTBIT;
				end if;
			
			when SEND_STARTBIT			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_state_next <= SEND_SLAVE_ADRESS; 
					sda_data_next <= CAM_ADDRESS_WR;
		
					i2c_bytestate_next <= B0;
				end if;
									
			when SEND_SLAVE_ADRESS		=>
				if(i2c_bytestate = WAIT_ACK and sdc_counter = COUNTER_NEXTSTATE)
				then								
					--sda_sig <= data_buffer(23);
					sda_data_next <= data_buffer(23 downto 16);
					
					i2c_bytestate_next <= B0;
					i2c_state_next <= SEND_REGISTER_ADRESS;
				end if;
				
			when SEND_REGISTER_ADRESS	=>
				if(i2c_bytestate = WAIT_ACK and sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= data_buffer(15);
					sda_data_next <= data_buffer(15 downto 8);
					
					i2c_bytestate_next <= B0;
					i2c_state_next <= SEND_DATA_HIGH;
				end if;
				
			when SEND_DATA_HIGH			=>
				if(i2c_bytestate = WAIT_ACK and sdc_counter = COUNTER_NEXTSTATE)
				then
					--sda_sig <= data_buffer(7);
					sda_data_next <= data_buffer(7 downto 0);
	
					i2c_bytestate_next <= B0;
					i2c_state_next <= SEND_DATA_LOW;
				end if;
					
			when SEND_DATA_LOW			=>
				if(i2c_bytestate = WAIT_ACK and sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_bytestate_next <= IDLE;
					i2c_state_next <= SEND_FINISHED;
				end if;
				
			when SEND_FINISHED			=>
				if(sdc_counter = COUNTER_NEXTSTATE)
				then
					i2c_state_next <= STOP_CLK;
					sda_sig <= '1';
				end if;
			when STOP_CLK					=>
					i2c_state_next <= IDLE;
			
		end case;
        
    -- SCARTS Extension: write memory mapped addresses
    if ((extsel = '1') and (exti.write_en = '1')) then
      case exti.addr(4 downto 2) is
        when "000" =>
          if ((exti.byte_en(0) = '1') or (exti.byte_en(1) = '1')) then
            v.ifacereg(STATUSREG)(STA_INT) := '1';
            v.ifacereg(CONFIGREG)(CONF_INTA) :='0';
          else
            if ((exti.byte_en(2) = '1')) then
              v.ifacereg(2) := exti.data(23 downto 16);
            end if;
            if ((exti.byte_en(3) = '1')) then
              v.ifacereg(3) := exti.data(31 downto 24);
            end if;
          end if;
				
				when "001" =>
					if i2c_state = IDLE then
						--i2c_state_next <= START_CLK;
						i2c_state_next <= SEND_STARTBIT;
						sdc_counter_next <= 1;
						data_buffer_next <= exti.data(23 downto 0);
					end if;

        when others =>
          null;
      end case;
    end if;
    
    -- combine soft- and hard-reset
    rstint <= not RST_ACT;
    if exti.reset = RST_ACT or r.ifacereg(CONFIGREG)(CONF_SRES) = '1' then
      rstint <= RST_ACT;
    end if;
    
    -- reset interrupt
    if r.ifacereg(STATUSREG)(STA_INT) = '1' and r.ifacereg(CONFIGREG)(CONF_INTA) ='0' then
      v.ifacereg(STATUSREG)(STA_INT) := '0';
    end if; 
    exto.intreq <= r.ifacereg(STATUSREG)(STA_INT);
	
		sda_buf_next <= sda_sig;

    r_next <= v;
	
	end process;
	
end;


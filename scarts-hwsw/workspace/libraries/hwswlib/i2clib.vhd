------------------------------------------------------------------------------
--  This file is a part of the GRLIB VHDL IP LIBRARY
--  Copyright (C) 2003 - 2008, Gaisler Research
--  Copyright (C) 2008 - 2010, Aeroflex Gaisler
--
--  This program is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This program is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
--  You should have received a copy of the GNU General Public License
--  along with this program; if not, write to the Free Software
--  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA 
-----------------------------------------------------------------------------
-- Package: 	misc
-- File:	misc.vhd
-- Author:	Jiri Gaisler - Gaisler Research
-- Description:	Misc models
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.scarts_pkg.all;

--library grlib;
--use grlib.amba.all;

package i2clib is

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

	component i2cmaster
	generic(
		-- APB generics
		--pindex  : integer := 0;                -- slave bus index
		--paddr   : integer := 0;
		--pmask   : integer := 16#fff#;
		--pirq    : integer := 0;                -- interrupt index
		--oepol   : integer range 0 to 1 := 0;   -- output enable polarity
		constant CAM_ADDRESS_RD		: std_logic_vector(7 downto 0) := "10111011";	-- 0xBB
		constant CAM_ADDRESS_WR		: std_logic_vector(7 downto 0) := "10111010");	-- 0xBA
	port (
		rst				: in std_logic;           -- Synchronous reset
		clk				: in std_logic;
		
		-- APB signals
		--apbi			: in  apb_slv_in_type;
		--apbo			: out apb_slv_out_type;	
		
		extsel			: in	std_logic;
		exti				: in  module_in_type;
		--exto			: out module_out_type;
		
		-- I2C signals
		--i2ci			: in  i2c_in_type;
		i2co				: out i2c_out_type
		);
	end component;
end;



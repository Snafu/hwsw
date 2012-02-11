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



library grlib;
use grlib.amba.all;
use grlib.devices.all;
use grlib.stdlib.all;

library gaisler;
use gaisler.misc.all;

use work.scarts_pkg.all;

package hwswlib is

	component dispctrl
	  generic (
			hindex      : integer := 0;
			hirq        : integer := 0
		);
	  
	  port (
			ahbready_dbg	: out std_logic;
			rst						: in std_logic;           -- Synchronous reset
			clk     	 	 	: in std_logic;
			ahbi					: in  ahb_mst_in_type;
			ahbo    		  : out ahb_mst_out_type;
			fval					: in std_logic;
			rdaddress 		: out std_logic_vector(8 downto 0);
			rddata    		: in std_logic_vector(31 downto 0);
			blockrdy  		: in std_logic;
			init_ready		: in std_logic
		);
	end component;

	component bayerbuffer
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
		);
	end component;

	component buttons is
		port (
			rst				: in std_logic;           -- Synchronous reset
			clk				: in std_logic;
			
			extsel		: in	std_logic;
			exti			: in  module_in_type;
			exto			: out module_out_type;

			key3			: in std_logic;
			key2			: in std_logic;
			key1			: in std_logic;
			
			sw17			: in std_logic;
			sw16			: in std_logic;
			sw15			: in std_logic;
			sw14			: in std_logic;
			sw13			: in std_logic;
			sw12			: in std_logic;
			sw11			: in std_logic;
			sw10			: in std_logic;
			sw9				: in std_logic;
			sw8				: in std_logic;
			sw7				: in std_logic;
			sw6				: in std_logic;
			sw5				: in std_logic;
			sw4				: in std_logic;
			sw3				: in std_logic;
			sw2				: in std_logic;
			sw1				: in std_logic;
			sw0				: in std_logic
			);
	end component;
	
end;



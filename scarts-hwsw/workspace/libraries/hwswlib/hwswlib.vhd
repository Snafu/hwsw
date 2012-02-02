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

library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.misc.all;

package hwswlib is
	type writestate_type is (IDLE, STARTBLOCK, HANDLEBLOCK);

	component dispctrl
	  generic(
		 pindex      : integer := 0;
		 paddr       : integer := 0;
		 pmask       : integer := 16#fff#;
		 hindex      : integer := 0;
		 hirq        : integer := 0;
		 ahbaccsz    : integer := 32
		 );
	  
	  port (
		 rst       : in std_logic;           -- Synchronous reset
		 clk       : in std_logic;
		 apbi      : in apb_slv_in_type;
		 apbo      : out apb_slv_out_type;
		 ahbi      : in  ahb_mst_in_type;
		 ahbo      : out ahb_mst_out_type;
		 rdaddress : out std_logic_vector(8 downto 0);
		 rddata    : in std_logic_vector(31 downto 0);
		 blockrdy  : in std_logic
		 );
	end component;
	
	
end;



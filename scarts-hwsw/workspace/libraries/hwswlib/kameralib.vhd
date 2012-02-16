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

--library grlib;
--use grlib.amba.all;
--use grlib.devices.all;
--use grlib.stdlib.all;
--use gaisler.misc.all;
--library techmap;
--use techmap.gencomp.all;
--library gaisler;

package kameralib is

	type sram_ctrl_t is record
		addr		: std_logic_vector(19 downto 0);
		we			: std_logic;
		oe			: std_logic;
		ce			: std_logic;
		ub			: std_logic;
		lb			: std_logic;
	end record;


	type sram_t is record
		addr		: std_logic_vector(19 downto 0);
		data		: std_logic_vector(15 downto 0);
		we			: std_logic;
		oe			: std_logic;
		ce			: std_logic;
		ub			: std_logic;
		lb			: std_logic;
	end record;

	type state_t is (WAIT_INIT, NOINIT, WAITFRAME, FRAMEEND, WAITFIRST, FIRST, WAITNORMAL, NORMAL);
	
	component kamera
		port (
			-- DEBUG
			camstate				: out state_t;
			bb_rdreq_dbg				: out std_logic;
			bb_wrreq_dbg				: out std_logic;
			bb_clearfifo_dbg		: out std_logic;
	
	
			rst							: in std_logic;	-- Synchronous reset
			clk							: in std_logic;
			fval						: in std_logic;
			lval						: in std_logic;
			pixdata					: in std_logic_vector(11 downto 0);
			
			dp_data					: out std_logic_vector(31 downto 0);
			dp_wren					: out std_logic;
			dp_wraddr				: out std_logic_vector(8 downto 0);
			
			pixelburstReady	: out std_logic;
	
			init_ready			: in std_logic
		);
	end component;

	component bayerbuffer
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			sclr	: IN STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
			wrreq		: IN STD_LOGIC
		);
	end component;

	component dp_pixelram
		PORT
    (
			data				: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			rdaddress		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
			rdclock			: IN STD_LOGIC ;
			wraddress		: IN STD_LOGIC_VECTOR (8 DOWNTO 0);
			wrclock			: IN STD_LOGIC  := '1';
			wren				: IN STD_LOGIC  := '0';
			q						: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
		);
	end component;

end;



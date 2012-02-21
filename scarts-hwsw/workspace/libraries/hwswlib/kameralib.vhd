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

library work;
use work.scarts_pkg.all;

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
	component kameractrl is
		port (
			rst							: in	std_logic;
			clk							: in	std_logic;
			extsel					: in	std_logic;
			exti						: in  module_in_type;
			exto						: out module_out_type;

			yR_fac					: out std_logic_vector(8 downto 0);
			yG_fac					: out std_logic_vector(8 downto 0);
			yB_fac					: out std_logic_vector(8 downto 0);
			yMin						: out integer range 0 to 255;
			yMax						: out integer range 0 to 255;

			cbR_fac					: out std_logic_vector(8 downto 0);
			cbG_fac					: out std_logic_vector(8 downto 0);
			cbB_fac					: out std_logic_vector(8 downto 0);
			cbMin						: out integer range 0 to 255;
			cbMax						: out integer range 0 to 255;

			crR_fac					: out std_logic_vector(8 downto 0);
			crG_fac					: out std_logic_vector(8 downto 0);
			crB_fac					: out std_logic_vector(8 downto 0);
			crMin						: out integer range 0 to 255;
			crMax						: out integer range 0 to 255;

			output_mode			:	out	std_logic
	    );
	end component;
	
	component kamera
		generic (
			FILTERADDRLEN			: integer range 2 to integer'high;
			FILTERDATALEN			: integer range 2 to integer'high
		);
		port (
			-- DEBUG
			camstate						: out state_t;
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

			filter_addr			: out std_logic_vector(FILTERADDRLEN-1 downto 0);
			filter_data			: out std_logic_vector(FILTERDATALEN-1 downto 0);
			filter_we				: out std_logic;

			yR_fac					: in std_logic_vector(8 downto 0);
			yG_fac					: in std_logic_vector(8 downto 0);
			yB_fac					: in std_logic_vector(8 downto 0);
			yMin						: in integer range 0 to 255;
			yMax						: in integer range 0 to 255;

			cbR_fac					: in std_logic_vector(8 downto 0);
			cbG_fac					: in std_logic_vector(8 downto 0);
			cbB_fac					: in std_logic_vector(8 downto 0);
			cbMin						: in integer range 0 to 255;
			cbMax						: in integer range 0 to 255;

			crR_fac					: in std_logic_vector(8 downto 0);
			crG_fac					: in std_logic_vector(8 downto 0);
			crB_fac					: in std_logic_vector(8 downto 0);
			crMin						: in integer range 0 to 255;
			crMax						: in integer range 0 to 255;

			output_mode			:	in	std_logic;

			init_ready			: in std_logic
		);
	end component;

	component bayerbuffer
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			sclr		: IN STD_LOGIC ;
			q				: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
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
	
	component yCbCrMUL
	PORT
	(
		clock0          : IN STD_LOGIC  := '1';
		dataa_0         : IN STD_LOGIC_VECTOR (7 DOWNTO 0) :=  (OTHERS => '0');
		dataa_1         : IN STD_LOGIC_VECTOR (7 DOWNTO 0) :=  (OTHERS => '0');
		dataa_2         : IN STD_LOGIC_VECTOR (7 DOWNTO 0) :=  (OTHERS => '0');
		datab_0         : IN STD_LOGIC_VECTOR (8 DOWNTO 0) :=  (OTHERS => '0');
		datab_1         : IN STD_LOGIC_VECTOR (8 DOWNTO 0) :=  (OTHERS => '0');
		datab_2         : IN STD_LOGIC_VECTOR (8 DOWNTO 0) :=  (OTHERS => '0');
		result          : OUT STD_LOGIC_VECTOR (16 DOWNTO 0)
	);
	END component;

end;



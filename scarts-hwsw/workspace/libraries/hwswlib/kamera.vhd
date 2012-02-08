-----------------------------------------------------------------------------
-- Entity:      kamera
-- File:        kamera.vhd
-- Author:      Christopher Gabriel
-- Modified:    
-- Contact:     stuff@c-gabriel.at
-- Description: Cam readout
-----------------------------------------------------------------------------
-- GRLIB2 CORE
-- VENDOR:      VENDOR_HWSW
-- DEVICE:      HWSW_CAM
-- VERSION:     0
-- AHBMASTER:   0
-- APB:         0
-- BAR: 0       TYPE: 0010      PREFETCH: 0     CACHE: 0        DESC: IO_AREA
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

library work;
use work.kameralib.all;

entity kamera is

  generic(
		pindex      : integer := 0;
		paddr       : integer := 0;
		pmask       : integer := 16#fff#;
		hindex      : integer := 0;
		hirq        : integer := 0;
		ahbaccsz    : integer := 32
	);
  
	port (
		rst				: in std_logic;           -- Synchronous reset
		clk				: in std_logic;
		pixclk			: in std_logic;
		fval				: in std_logic;
		lval				: in std_logic;
		pixdata			: in std_logic_vector(11 downto 0);
		--sram_ctrl		: out sram_ctrl_t;
		--sram_data		: buffer std_logic_vector(15 downto 0);
		
		dp_data			: out std_logic_vector(31 downto 0);
		dp_wren			: out std_logic;
		dp_wraddr		: out std_logic_vector(8 downto 0);
		
		pixelburstReady	: out std_logic;
		
		whichLine_dbg	: out std_logic;
		burstCount_dbg	: out std_logic_vector(4 downto 0)
    );
end ;

architecture rtl of kamera is
	constant ROWSIZE : integer := 800;
	constant LINESIZE : integer := 480;
	constant BLOCKSIZE : integer := 32;

	type state_t is (NOINIT,IDLE,LINEA,LINEB);
	
	type count_t is (FIRST, SECOND);

	signal pixState, pixState_n : state_t := NOINIT;
	signal fval_old, fval_old_n : std_logic := '1';
	signal lval_old, lval_old_n : std_logic := '1';
	signal pixclk_old, pixclk_old_n : std_logic := '0';
	signal pixelCount, pixelCount_n : integer range 0 to 400 := 0;
	signal burstCount, burstCount_n : integer range 0 to 20 := 0;
	signal pixelburstReady_n : std_logic := '0';
	signal lineCount, lineCount_n : integer range 0 to LINESIZE;
	signal rowCount, rowCount_n : integer range 0 to ROWSIZE;
	signal whichLine, whichLine_n : count_t;
	signal whichPixel, whichPixel_n : count_t;
	
begin

	readout : process(rst,clk,fval,fval_old,lval,lval_old,pixclk,pixclk_old,pixState,pixelCount,lineCount,rowCount,whichLine, whichPixel, burstCount)
		variable fval_rising : std_logic;
		variable lval_rising : std_logic;
		variable pixclk_rising : std_logic;
	begin
		pixState_n <= pixState;
		fval_old_n <= fval;
		lval_old_n <= lval;
		pixclk_old_n <= pixclk;
		pixelCount_n <= pixelCount;
		pixelburstReady_n <= '0';
		lineCount_n <= lineCount;
		rowCount_n <= rowCount;
		whichLine_n <= whichLine;
		whichPixel_n <= whichPixel;	
		burstCount_n <= burstCount;
		dp_wren <= '0';
		
		-- see datasheet page 55: capture data on FALLING EDGE of pixclock
		if(pixclk = '0' and pixclk /= pixclk_old)
		then
			-- reset ALL COUNTERS
			if(fval = '0' and lval = '0')
			then
				lineCount_n <= 0;
				rowCount_n <= 0;
				whichLine_n <= FIRST;
				pixelCount_n <= 0;
				
			--  wait for LVAL
			elsif(fval = '1' and lval = '0')
			then
				burstCount_n <= 0;
				
			-- ILLEGAL state - should not happen
			elsif(fval = '0' and lval = '1')
			then
			
			-- NEW pixeldata!
			elsif(fval = '1' and lval = '1')
			then
				if(whichPixel = FIRST)
				then
					whichPixel_n <= SECOND;
				else
					whichPixel_n <= FIRST;
					
					pixelCount_n <= pixelCount + 1;		-- only count every 2nd pixelfragment
					
					if(whichLine = SECOND)
					then
						burstCount_n <= burstCount + 1;
						if(burstCount = 15)
						then
							burstCount_n <= 0;
							pixelburstReady_n <= '1';
						end if;
		
					end if;
				end if;
			
			end if;

		end if;
						
		if(pixelCount = 400)
		then
			pixelCount_n <= 0;
			if(whichLine = FIRST)
			then
				whichLine_n <= SECOND;
			else
				whichLine_n <= FIRST;
			end if;
		end if;
		
  end process; 
  

  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk, rst)
  begin
  	if(rst = '0')
		then
			pixState <= NOINIT;
			fval_old <= '0';
			lval_old <= '0';
			pixclk_old <= '0';
			pixelCount <= 0;
			pixelburstReady <= '0';
			lineCount <= 0;
			rowCount <= 0;
			whichLine <= FIRST;
			whichLine_dbg <= '0';
			whichPixel <= FIRST;
			burstCount <= 0;
		else
			if rising_edge(clk)
			then
				pixState <= pixState_n;
				fval_old <= fval_old_n;
				lval_old <= lval_old_n;
				pixclk_old <= pixclk_old_n;
				pixelCount <= pixelCount_n;
				pixelburstReady <= pixelburstReady_n;
				lineCount <= lineCount_n;
				rowCount <= rowCount_n;
				whichLine <= whichLine_n;
				
				if( whichLine_n = FIRST)
				then
					whichLine_dbg <= '0';
				else
					whichLine_dbg <= '1';
				end if;
				whichPixel <= whichPixel_n;
				burstCount <= burstCount_n;
				
				burstCount_dbg <= conv_std_logic_vector(burstCount_n, 5);
			end if;
		end if;
	end process;
end;


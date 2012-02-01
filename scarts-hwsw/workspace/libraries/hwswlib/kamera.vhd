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
		sram_ctrl		: out sram_ctrl_t;
		sram_data		: buffer std_logic_vector(15 downto 0);
		
		dp_data			: out std_logic_vector(31 downto 0);
		dp_wren			: out std_logic;
		dp_wraddr		: out std_logic_vector(8 downto 0);
		
		pixelburstReady	: out std_logic
    );
end ;

architecture rtl of kamera is
  
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
	
	type color_t is (R,G,B);
	type pixel_t is array(color_t'left to color_t'right) of std_logic_vector(7 downto 0);
	type pixline_t is array(1 to 800) of pixel_t;
	type line_t is (FIRST, SECOND);
	
	signal pixclk_old		: std_logic;
	
	signal fval_old		: std_logic;
	signal fval_old_next	: std_logic;
	
	signal lval_old		: std_logic;
	signal lval_old_next	: std_logic;
	
	signal linecnt			: integer range 0 to 900; 
	signal linecnt_next	: integer range 0 to 900;
  
	signal rowcnt			: integer range 0 to 500;
	signal rowcnt_next	: integer range 0 to 500;
	
	signal whichline		: line_t;
	signal whichline_next: line_t;
	
	signal pixelB			: std_logic_vector(7 downto 0);
	signal pixelB_next	: std_logic_vector(7 downto 0);
	
	signal pixelG			: std_logic_vector(7 downto 0);
	signal pixelG_next	: std_logic_vector(7 downto 0);
	
	signal dp_cnt			: integer range 0 to 500;
	signal dp_cnt_next	: integer range 0 to 500;
	
	signal firstPixel			: std_logic;
	signal firstPixel_next	: std_logic;
	
	signal burstCnt		:	integer range 0 to 30;
	signal burstCnt_next	:	integer range 0 to 30;
		  
begin

	readout : process(rst, fval, fval_old, lval, lval_old, whichline, pixdata ,pixclk, pixclk_old, rowcnt, linecnt, pixelG, pixelB, dp_cnt, sram_data, firstPixel, firstPixel_next, burstCnt, burstCnt_next)
	begin
				
		pixelburstReady <= '0';
		
		burstCnt_next <= burstCnt;
		firstPixel_next <= firstPixel;
				
		dp_data <= "00000000000000000000000000000000";
		dp_wraddr(8 downto 0) <= conv_std_logic_vector(dp_cnt, 9);
		dp_wren <= '1';
		dp_cnt_next <= dp_cnt;
		
		rowcnt_next <= rowcnt;
		linecnt_next <= linecnt;
		
		pixelG_next <= pixelG;
		pixelB_next <= pixelB;
		whichline_next <= whichline;
		
		fval_old_next <= fval;
		lval_old_next <= lval;
		
		sram_ctrl.we <= '1';	
		-- can be LOW all the time according to datasheet
		sram_ctrl.oe <= '0';
		sram_ctrl.ce <= '0';
		sram_ctrl.ub <= '0';
		sram_ctrl.lb <= '0';	
		-- we only need 10 bit adress(800 pixel per line) here, so ignore bits 10-19
		sram_ctrl.addr(9 downto 0) <= conv_std_logic_vector(rowcnt, 10);
		
		-- rising edge of FVAL -> NEW FRAME starts
		if(fval_old /= fval and fval = '1')
		then
			whichline_next <= FIRST;
			rowcnt_next  <= 0;
			linecnt_next <= 0;
			dp_cnt_next <= 0;
		end if;
		
		-- rising edge of LVAL -> NEW LINE starts
		-- initialise all counters
		if(lval_old /= lval and lval = '1')
		then
		
			rowcnt_next  <= 0;
			linecnt_next <= linecnt + 1;
			burstCnt_next <= 0;
			firstPixel_next <= '0';
			
			
			if(whichline = FIRST)
			then
				whichline_next <= SECOND;
			else
				whichline_next <= FIRST;
			end if;
		
		end if;
		
		-- rising edge of pxclk -> valid BAYER data from cam
		if fval = '1' and lval = '1' and pixclk_old /= pixclk and pixclk = '1'
		then
			rowcnt_next  <= rowcnt + 1;
			
			-- FIRST LINE: save COMPLETE line to SRAM
			if(whichline = FIRST)
			then
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';
					pixelG_next <= pixdata(11 downto 4);
				else	
					firstPixel_next <= '0';
					sram_ctrl.we <= '0';
					--sram_ctrl.ce <= '0';
					sram_data(7 downto 0) <= pixdata(7 downto 0);	-- save RED pixel
					sram_data(15 downto 8) <= pixelG;					-- save buffered GREEN1 pixel
				end if;
				
			-- SECOND LINE: calculate new pixels
			else
				-- save BLUE part of pixel
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';
					pixelB_next <= pixdata(11 downto 4);
					--sram_ctrl.ce <= '0';
					--sram_ctrl.oe <= '0';
					
				else
					firstPixel_next <= '0';
					dp_cnt_next <= dp_cnt + 1;
				
					dp_wren <= '0';
					dp_data(7 downto 0)   <= sram_data(7  downto 0);
					--dp_data(15 downto 8)  <= (sram_data(15 downto 8) + pixelG);
					dp_data(23 downto 16) <= pixelB;
					burstCnt_next <= burstCnt + 1;
					
					if( burstCnt = 16)
					then
						pixelburstReady <= '1';
						burstCnt_next <= 0;
					end if;
				end if;
			
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
		pixclk_old <= '0';
		fval_old <= '0';
		lval_old <= '0';
		
		linecnt <= 0;
		rowcnt <=  0;
		dp_cnt <= 0;
		
		whichline <= FIRST;
		
		pixelB <= "00000000";
		pixelG <= "00000000";
		
		firstPixel <= '0';
		burstCnt <= 0;
		
	else
		if rising_edge(clk)
		then
			pixclk_old <= pixclk;
			fval_old <= fval_old_next;
			lval_old <= lval_old_next;
			
			linecnt <= linecnt_next;
			rowcnt <= rowcnt_next;
			
			dp_cnt <= dp_cnt_next;
			
			whichline <= whichline_next;
			
			pixelB <= pixelB_next;
			pixelG <= pixelG_next;
							
			firstPixel <= firstPixel_next;	
			burstCnt <= burstCnt_next;
			
		end if;
	end if;
	end process;
 
  
end;


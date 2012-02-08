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
  
  --constant PIXELBURSTLEN	: integer := 3;
  constant PIXELBURSTLEN	: integer := 15;
  
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
	
	type line_t is (FIRST, SECOND);
	
	signal pixclk_old			: std_logic;
	signal pixclk_old_next	: std_logic;
	
	signal fval_old		: std_logic;
	signal fval_old_next	: std_logic;
	
	signal lval_old		: std_logic;
	signal lval_old_next	: std_logic;
  
	signal rowcnt			: integer range 0 to 500;
	signal rowcnt_next	: integer range 0 to 500;
	signal linecnt			: integer range 0 to 500;
	signal linecnt_next	: integer range 0 to 500;
	
	signal whichline		: line_t;
	signal whichline_next: line_t;
	
	signal pixelB			: std_logic_vector(7 downto 0);
	signal pixelB_next	: std_logic_vector(7 downto 0);
	
	signal pixelG			: std_logic_vector(7 downto 0);
	signal pixelG_next	: std_logic_vector(7 downto 0);
	
	signal pixelR			: std_logic_vector(7 downto 0);
	signal pixelR_next	: std_logic_vector(7 downto 0);
	
	signal dp_cnt			: integer range 0 to 512;
	signal dp_cnt_next	: integer range 0 to 512;
	
	signal firstPixel			: std_logic;
	signal firstPixel_next	: std_logic;
	
	signal burstCnt		:	integer range 0 to 30;
	signal burstCnt_next	:	integer range 0 to 30;
	
	signal frameCnt		:	integer range 0 to 10;
	signal frameCnt_next	:	integer range 0 to 10;
	
	signal dp_buf			: std_logic_vector(31 downto 0);
	signal dp_buf_next	: std_logic_vector(31 downto 0);
	
	signal sram_buf			: std_logic_vector(15 downto 0);
	signal sram_buf_next	: std_logic_vector(15 downto 0);
	
	
	type matrix_t is array(0 to 399) of std_logic_vector(239 downto 0);
	
	signal bitmapORIG		: matrix_t;
	signal bitmapEROSION	: matrix_t;
	signal bitmapDILATION: matrix_t;
	
	signal origXCnt			: integer range 0 to 400;
	signal origXCnt_next		: integer range 0 to 400;
	signal origYCnt			: integer range 0 to 240;
	signal origYCnt_next		: integer range 0 to 240;
	
	signal dilationXCnt			: integer range 0 to 400;
	signal dilationXCnt_next	: integer range 0 to 400;
	signal dilationYCnt			: integer range 0 to 240;
	signal dilationYCnt_next	: integer range 0 to 240;
	
	signal erosionXCnt			: integer range 0 to 400;
	signal erosionXCnt_next		: integer range 0 to 400;
	signal erosionYCnt			: integer range 0 to 240;
	signal erosionYCnt_next		: integer range 0 to 240;

	type filter_t is(IDLE, BUSY, FINISHED);
	
	signal erosionState			: filter_t;
	signal erosionState_next	: filter_t;
	
	signal dilationState			: filter_t;
	signal dilationState_next	: filter_t;
	
	signal startDilation			: std_logic;
	signal startDilation_next	: std_logic;
	
	signal startErosion			: std_logic;
	signal startErosion_next	: std_logic;
	
begin


--	--
--	-- DILATION FILTER
--	--
--	-- gets signaled when EROSION is done
--	imageProcessingDilation : process(dilationXCnt, dilationYCnt, startDilation, startDilation_next, dilationState)
--	begin
--				
--		dilationXCnt_next <= dilationXCnt;
--		dilationYCnt_next <= dilationYCnt;
--		dilationState_next <= dilationState;
--	
--		case dilationState is
--			when	IDLE =>
--				if(startDilation /= startDilation_next and startDilation_next = '1')
--				then
--					erosionState_next <= BUSY;
--				end if;
--			when	BUSY =>
--			
--			when	FINISHED =>
--		
--		end case;
--		
--	
--	end process;
--	
--	
--	--
--	--	EROSION FILTER
--	--
--	-- gets signaled when complex 400x240 x 1bit picture(after skinfilter) is ready
--	imageProcessingErosion : process(erosionXCnt, erosionYCnt)
--	begin
--	
--		erosionXCnt_next <= erosionXCnt;
--		erosionYCnt_next <= erosionYCnt;
--		erosionState_next <= erosionState;
--		
--		case erosionState is
--			when	IDLE =>
--			
--			when	BUSY =>
--			
--			when	FINISHED =>
--		
--		end case;
--		
--	end process;
--	
	

	readout : process(rst, fval, fval_old, lval, lval_old, whichline, pixdata ,pixclk, pixclk_old, rowcnt, pixelG, pixelB, pixelR, dp_cnt, sram_data, firstPixel, firstPixel_next, burstCnt, burstCnt_next, linecnt, frameCnt, dp_buf, sram_buf)
	begin
	
		startErosion_next <= startErosion;
		startDilation_next <= startDilation;
						
		burstCnt_next <= burstCnt;
		firstPixel_next <= firstPixel;			
		
		rowcnt_next <= rowcnt;
		linecnt_next <= linecnt;
		pixelG_next <= pixelG;
		pixelB_next <= pixelB;
		pixelR_next <= pixelR;
		
		whichline_next <= whichline;	
		fval_old_next <= fval;
		lval_old_next <= lval;
		pixclk_old_next <= pixclk;
				
		pixelburstReady <= '0';
		
		frameCnt_next <= frameCnt;
		
		dp_cnt_next <= dp_cnt;	
		dp_buf_next <= dp_buf;
		sram_buf_next <= sram_buf;
						
--		if(frameCnt = 0)
--		then
--			dp_data <= x"00000000";	
--		elsif(frameCnt = 1)
--		then
--			dp_data <= x"000000FF";
--		elsif(frameCnt = 2)
--		then
--			dp_data <= x"0000FF00";
--		else
--			dp_data <= x"00FF0000";
--		end if;
		
		--
		-- DUALPORT RAM CONTROL
		--
		-- DATA -> RAM: always assert signals here - WR_EN will get falling flank later

-- TEMP disabled wg. meminit - test
dp_data <= dp_buf;
if(dp_cnt > 0)
then	
dp_wraddr(8 downto 0) <= conv_std_logic_vector((dp_cnt-1), 9);
else
dp_wraddr(8 downto 0) <= "000000000";
end if;
		
--dp_wren <= '1';
dp_wren <= '0';
		
		--
		-- SRAM CONTROL
		--
		sram_data <= sram_buf;
		sram_ctrl.we <= '1';	
		-- can be LOW all the time according to datasheet
		sram_ctrl.oe <= '0';
		sram_ctrl.ce <= '0';
		sram_ctrl.ub <= '0';
		sram_ctrl.lb <= '0';	
		
		-- we only need 9 bit adress: 800 pixel per line, but SRAM-datawidth=16bit...
		
		if(whichline = FIRST)
		then
			if(rowcnt > 0)
			then
				-- when WRITING to SRAM, rowcnt is too high(+1), see [MARK1]
				sram_ctrl.addr(8 downto 0) <= conv_std_logic_vector((rowcnt-1), 9);
			else
				sram_ctrl.addr(8 downto 0) <= "000000000";
			end if;
		else
			-- when READING from SRAM no additional cylce is needed to get proper data
			sram_ctrl.addr(8 downto 0) <= conv_std_logic_vector(rowcnt, 9);
		end if;
		-- ... so save 2 Byte at one adress, ignore bits 10-19:
		sram_ctrl.addr(19 downto 9) <= (others => '0');
		
		--
		-- NEW FRAME
		--
		-- rising edge of FVAL
		if(fval_old /= fval and fval = '1')
		then
			whichline_next <= FIRST;
			rowcnt_next  <= 0;
			linecnt_next <= 0;
			dp_cnt_next <= 0;
			burstCnt_next <= 0;
			firstPixel_next <= '0';
		
			if(frameCnt < 3)
			then
				frameCnt_next <= frameCnt + 1;
			else
				frameCnt_next <= 0;
			end if;		
		end if;
		
--		if(fval = '0')
--		then
--			whichline_next <= FIRST;
--			rowcnt_next  <= 0;
--			linecnt_next <= 0;
--			dp_cnt_next <= 0;
--			burstCnt_next <= 0;
--			firstPixel_next <= '0';
--		end if;
--		
--		
--		if (lval = '0')
--		then
--			rowcnt_next  <= 0;
--			dp_cnt_next <= 0;
--			burstCnt_next <= 0;
--			firstPixel_next <= '0';
--		end if;
		
		--
		-- NEW LINE
		--
		-- rising edge of LVAL
		if(lval_old /= lval and lval = '1')
		then
			linecnt_next <= linecnt + 1;
			
			if(linecnt /= 0)
			then
				if(whichline = FIRST)
				then
					whichline_next <= SECOND;
				else
					whichline_next <= FIRST;
				end if;
			end if;
		end if;
		
		--
		-- PROCESS BAYER PIXEL PATTERN
		--
		-- rising edge of pxclk -> valid BAYER data from cam
		if fval = '1' and lval = '1' and pixclk_old /= pixclk and pixclk = '1'
		then	
		
			-- FIRST LINE: save COMPLETE line to SRAM
			if(whichline = FIRST)
			then
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';

					-- buffer G1 Value
					sram_buf_next(15 downto 8) <= pixdata(11 downto 4);
					
					if(rowcnt > 0)
					then
						sram_ctrl.we <= '0';
					end if;
				else
		
					-- buffer RED value
					sram_buf_next(7 downto 0) <= pixdata(11 downto 4);		
					-- prepare next SRAM adress
					-- because SRAM values+address will be written with NEXT - signals, this rowcnt is too high[MARK1]
					rowcnt_next  <= rowcnt + 1;
					firstPixel_next <= '0';
													
			end if;
								
			-- SECOND LINE: calculate new pixels and save to DP-RAM(1pixel from DP-RAM will become 2x2 miniframe @ SVGA
			else
				-- save BLUE part of pixel
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';
					pixelB_next <= pixdata(11 downto 4);
					
					-- save the last 4 Pixel to DP-RAM
					-- must be done here because DP-RAM seems to need DATA and ADRESS first, then one cylce later WR_EN:
					if(rowcnt > 0)
					then
-- disabled TEMP to test with memINIT file
dp_wren <= '1';
--dp_wren <= '0';
					end if;
					
				else
					firstPixel_next <= '0';
					dp_cnt_next <= dp_cnt + 1;
					rowcnt_next  <= rowcnt + 1;
							
					-- get pixeldata from corresponding first line, save in DP RAM
					-- proper adress was already set one cycle earlier
										
					-- FIXME:ignore G2 for now...
					
					-- reading from SRAM: 
				-- disabled TEMP to test with memINIT file
dp_buf_next(23 downto 16)   <= sram_data(7  downto 0);
dp_buf_next(15 downto 8)  <= sram_data(15 downto 8);
dp_buf_next(7 downto 0) <= pixelB;
				
--
--
--	
-- TODO:
-- we just got a NEW RGB pixel, so this is the place to convert the RGB-pixel to yCbCr and apply the skinfilter!
-- there are 400 x 240 of that pixels
-- 1. save all of that 1bit - pixels to a DP-ram-instance
-- 2. apply erosion filter
-- 3. apply xxx- filter
-- 4. create histogramm, find maximal-values
--
-- MAYBE 2d - array will be a better choice...?
-- 
--

					burstCnt_next <= burstCnt + 1;
				
					-- because pixelburstReady is directly a port(no *_next - signals used)
					-- it will get signal too early(16. DP-Pixel will be written in the next cycle
					-- should be no problem because dispctrl must 'catch up'
					if( burstCnt = PIXELBURSTLEN)
					then
						--pixelburstReady <= '1';
						burstCnt_next <= 0;
					end if;					
				end if;	
			end if;
		end if;

		dp_wren <= '0';

		if frameCnt = 3 then
			pixelburstReady <= '1';
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
		rowcnt <=  0;
		linecnt <= 0;
		dp_cnt <= 0;
		
		whichline <= FIRST;
		
		pixelB <= "00000000";
		pixelG <= "00000000";
		pixelR <= "00000000";
		
		firstPixel <= '0';
		burstCnt <= 0;
		frameCnt <= 0;
		
		dp_buf <= x"00000000";
		sram_buf <= x"0000";
		
		startErosion <= '0';
		startDilation <= '0';
		
	else
		if rising_edge(clk)
		then
			pixclk_old <= pixclk_old_next;
			fval_old <= fval_old_next;
			lval_old <= lval_old_next;
			rowcnt <= rowcnt_next;
			linecnt <= linecnt_next;
			
			dp_cnt <= dp_cnt_next;
			
			whichline <= whichline_next;
			
			pixelB <= pixelB_next;
			pixelG <= pixelG_next;
			pixelR <= pixelR_next;
							
			firstPixel <= firstPixel_next;	
			burstCnt <= burstCnt_next;
			frameCnt <= frameCnt_next;
			
			dp_buf <= dp_buf_next;
			sram_buf <= sram_buf_next;
			
			startErosion <= startErosion_next;
			startDilation <= startDilation_next;
		end if;
	end if;
	end process;
 
  
end;


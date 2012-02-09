-----------------------------------------------------------------------------
-- Entity:      kamera
-- File:        kamera.vhd
-- Author:      Harald Glanzer
-- Modified:    
-- Contact:     hari@powpow.at
-- Description: Cam readout
-----------------------------------------------------------------------------
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
		
		pixelburstReady	: out std_logic;
		
		whichLine_dbg	: out std_logic;
		burstCount_dbg	: out std_logic_vector(4 downto 0)
    );
end ;

architecture rtl of kamera is
  
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
	
	type color_t is (R,G,B);
	type pixel_t is array(color_t'left to color_t'right) of std_logic_vector(7 downto 0);
	type pixline_t is array(1 to 800) of pixel_t;
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
	
	signal dp_cnt			: integer range 0 to 500;
	signal dp_cnt_next	: integer range 0 to 500;
	
	signal firstPixel			: std_logic;
	signal firstPixel_next	: std_logic;
	
	signal burstCnt		:	integer range 0 to 30;
	signal burstCnt_next	:	integer range 0 to 30;
	
	signal frameCnt		:	integer range 0 to 10;
	signal frameCnt_next	:	integer range 0 to 10;
	
	signal dp_buf			: std_logic_vector(31 downto 0);
	signal dp_buf_next	: std_logic_vector(31 downto 0);
	
	signal sram_data_buf			: std_logic_vector(15 downto 0);
	signal sram_data_buf_next	: std_logic_vector(15 downto 0);
		  
begin

	readout : process(rst, fval, fval_old, lval, lval_old, whichline, pixdata ,pixclk, pixclk_old, rowcnt, pixelG, pixelB, dp_cnt, sram_data, firstPixel, firstPixel_next, burstCnt, burstCnt_next, linecnt, frameCnt, pixelR, dp_buf, sram_data_buf)
	begin
						
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
		
		burstCnt_next <= burstCnt;
		
		sram_data_buf_next <= sram_data_buf;
							
		-- DUALPORT RAM CONTROL
		-- DATA -> RAM: always assert signals here - WR_EN will get falling flank
		
		dp_data <= dp_buf;	
		dp_wraddr(8 downto 0) <= conv_std_logic_vector(dp_cnt, 9);
		dp_wren <= '0';
		
		-- SRAM CONTROL
		--sram_data <= "0000000000000000";
		sram_data <= sram_data_buf;
		
if(whichLine = SECOND)
then
		sram_ctrl.we <= '1';	
else
		sram_ctrl.we <= '0';	
end if;

		-- can be LOW all the time according to datasheet
		sram_ctrl.oe <= '0';
		sram_ctrl.ce <= '0';
		sram_ctrl.ub <= '0';
		sram_ctrl.lb <= '0';	
		-- we only need 9 bit adress: 800 pixel per line, but SRAM-datawidth=16bit
		-- so save 2 Byte at one adress, ignore bits 10-19
		sram_ctrl.addr(8 downto 0) <= conv_std_logic_vector(rowcnt, 9);
		sram_ctrl.addr(19 downto 9) <= (others => '0');
		
		-- rising edge of FVAL -> NEW FRAME starts
		if(fval_old /= fval and fval = '1')
		then
			if(frameCnt < 3)
			then
				frameCnt_next <= frameCnt + 1;
			else
				frameCnt_next <= 0;
			end if;		
		end if;
		
		if(fval = '0')
		then
			whichline_next <= FIRST;
			rowcnt_next  <= 0;
			linecnt_next <= 0;
			dp_cnt_next <= 0;
			burstCnt_next <= 0;
			firstPixel_next <= '0';
		end if;
		
		if (lval = '0')
		then
			rowcnt_next  <= 0;
			dp_cnt_next <= 0;
			burstCnt_next <= 0;
			firstPixel_next <= '0';
		end if;
		
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
		
				
		-- FALLING edge of pxclk -> valid BAYER data from cam
		if fval = '1' and lval = '1' and pixclk_old /= pixclk and pixclk = '0'
		then				
			-- FIRST LINE: save COMPLETE line to SRAM
			-- Pattern: G1 - R - G1 - R ...
			if(whichline = FIRST)
			then
	
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';
					pixelG_next <= pixdata(11 downto 4);
		
				else
					-- save pixels from 'first' lines(Bayer: G1|R|G1|R... )
					-- save RED pixel and buffered GREEN1 pixel
					-- proper adress was already set one cylce earlier
					sram_ctrl.we <= '0';
		
					--sram_data(7 downto 0) <= pixdata(11 downto 4);		-- this is the RED share of the pixel
					--sram_data(15 downto 8) <= pixelG;						-- this is the GREEN_1 share of the pixel
					
					sram_data_buf_next(7 downto 0)  <= pixdata(11 downto 4);
					sram_data_buf_next(15 downto 8) <= pixelG;
					
					-- ... and prepare next SRAM adress
					rowcnt_next  <= rowcnt + 1;
					firstPixel_next <= '0';
													
					end if;
								
			-- SECOND LINE: calculate new pixels
			-- Pattern: B - G2 - B - G2 - B ...
			else
				-- save BLUE part of pixel
				if( firstPixel = '0' )
				then
					firstPixel_next <= '1';
					pixelB_next <= pixdata(11 downto 4);
					
					-- save the Pixel to DP-RAM
					-- must be done here because DP-RAM seems to need DATA and ADRESS first, one cylce later WR_EN:
					if(rowcnt > 0)
					then
						dp_wren <= '1';
					end if;
					
				else
					firstPixel_next <= '0';
					dp_cnt_next <= dp_cnt + 1;
					rowcnt_next  <= rowcnt + 1;
								
					-- get pixeldata from corresponding first line, save in SRAM
					-- proper adress was already set one cycle earlier
											
		
					-- so SOLLTE es funktionieren
					dp_buf_next(23 downto 16)   <= sram_data(7  downto 0);		-- save Red
					dp_buf_next(15 downto 8)  <= pixdata(11 downto 4);			-- save Green / TODO: mittelwert G1+G2
					--dp_buf_next(15 downto 8)  <= sram_data(15 downto 8);
					dp_buf_next(7 downto 0) <= pixelB;								-- save Blue
					burstCnt_next <= burstCnt + 1;
					
					if( burstCnt = PIXELBURSTLEN)
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
		burstCnt <= 0;
		sram_data_buf <=  x"0000";
		
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
			burstCnt <= burstCnt_next;
			
			dp_buf <= dp_buf_next;
			
			sram_data_buf <= sram_data_buf_next;

			if( whichLine_next = FIRST)
				then
					whichLine_dbg <= '0';
				else
					whichLine_dbg <= '1';
			end if;
			burstCount_dbg <= conv_std_logic_vector(burstCnt_next, 5);
		end if;
	end if;
	end process; 
end;


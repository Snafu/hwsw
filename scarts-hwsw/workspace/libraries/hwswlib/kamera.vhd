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
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.all;

library work;
use work.kameralib.all;


entity kamera is
	generic (
		FILTERADDRLEN			: integer range 2 to integer'high;
		FILTERDATALEN			: integer range 2 to integer'high
	);

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

		output_mode			:	in std_logic;

		init_ready			: in std_logic
    );
end ;

architecture rtl of kamera is
  
	constant MAXCOL				: integer := 802;
	constant LASTCOL			: integer := MAXCOL-2;
	constant MAXLINE			: integer := 482;
	constant LASTLINE			: integer := MAXLINE-2;

	-- DSP result offset
	constant yOFFSET			: integer := 16;
	constant cbOFFSET			: integer := 128;
	constant crOFFSET			: integer := 128;
	
	
	type dotline_t is array (0 to 1) of std_logic_vector(7 downto 0);
	type dotmatrix_t is array (0 to 1) of dotline_t;
	type colors_t is (SKIN, R, G, B);
	type pixel_t is array (colors_t'left to colors_t'right) of std_logic_vector(7 downto 0);

	--signal init_old, init_old_n							: std_logic := '0';

	signal state, state_next								: state_t;
	signal linecount, linecount_next				: std_logic_vector(9 downto 0);
	signal colcount, colcount_next					: std_logic_vector(10 downto 0);
	signal pixelcount, pixelcount_next			: std_logic_vector(10 downto 0);
	signal pixel														: pixel_t;
	signal dotmatrix												: dotmatrix_t;
	signal dpwren														: std_logic;
	signal dpaddr, dpaddr_next							: std_logic_vector(8 downto 0);

	signal pixelburstReady_next							: std_logic;

	signal bb_clearfifo, bb_clearfifo_next	: std_logic;
	signal bb_wrreq, bb_wrreq_next					: std_logic := '0';
	signal bb_in, bb_in_next								: std_logic_vector(7 downto 0);
	signal bb_rdreq, bb_rdreq_next					: std_logic := '0';
	signal bb_out_next											: std_logic_vector(7 downto 0);
	
	signal yR, yG, yB												: std_logic_vector(7 downto 0);
	signal yResult													: std_logic_vector(16 downto 0);
	
	signal cbR, cbG, cbB										: std_logic_vector(7 downto 0);
	signal cbResult													: std_logic_vector(16 downto 0);
	
	signal crR, crG, crB										: std_logic_vector(7 downto 0);
	signal crResult													: std_logic_vector(16 downto 0);

	signal filter_addr_sig									: std_logic_vector(FILTERADDRLEN-1 downto 0);
	signal filter_addr_next									: std_logic_vector(FILTERADDRLEN-1 downto 0);
	signal filter_data_sig									: std_logic_vector(FILTERDATALEN-1 downto 0);
	signal filter_data_next									: std_logic_vector(FILTERDATALEN-1 downto 0);
	signal filter_we_sig										: std_logic;
	signal filter_we_next										: std_logic;
	
	signal byteCount												: std_logic_vector(2 downto 0);
	signal byteCount_n											: std_logic_vector(2 downto 0);

	--signal yDBG, cbDBG, crDBG								: integer;
	--signal yDBGV, cbDBGV, crDBGV						: std_logic_vector(8 downto 0);
	
begin

	bb_rdreq_dbg <= bb_rdreq;
	bb_wrreq_dbg <= bb_wrreq;
	bb_clearfifo_dbg <= bb_clearfifo;

	bayerbuf : bayerbuffer PORT MAP (
		clock	 	=> clk,
		data	 	=> bb_in,
		rdreq	 	=> bb_rdreq,
		sclr	 	=> bb_clearfifo,
		q				=> bb_out_next,
		wrreq		=> bb_wrreq 
	);
	
	--	
	--	MULTIPLIERES for conversion RGB --> yCbCr
	--
	yMUL : yCbCrMUL PORT MAP (
		clock0   => clk,
		dataa_0  => yR,
		dataa_1  => yG,
		dataa_2  => yB,
		datab_0  => yR_fac, --std_logic_vector(to_signed(yRed,9)),
		datab_1  => yG_fac, --std_logic_vector(to_signed(yGreen,9)),
		datab_2  => yB_fac, --std_logic_vector(to_signed(yBlue,9)),
		result   => yResult
	);

	cbMUL : yCbCrMUL PORT MAP (
		clock0   => clk,
		dataa_0  => cbR,
		dataa_1  => cbG,
		dataa_2  => cbB,
		datab_0  => cbR_fac, --std_logic_vector(to_signed(cbRed,9)),
		datab_1  => cbG_fac, --std_logic_vector(to_signed(cbGreen,9)),
		datab_2  => cbB_fac, --std_logic_vector(to_signed(cbBlue,9)),
		result   => cbResult
	);

	crMUL : yCbCrMUL PORT MAP (
		clock0   => clk,
		dataa_0  => crR,
		dataa_1  => crG,
		dataa_2  => crB,
		datab_0  => crR_fac, --std_logic_vector(to_signed(crRed,9)),
		datab_1  => crG_fac, --std_logic_vector(to_signed(crGreen,9)),
		datab_2  => crB_fac, --std_logic_vector(to_signed(crBlue,9)),
		result   => crResult
	);

	camstate <= state;


	----------------------------------------------------------------------------
	-- Bayer converter FSM Control
	----------------------------------------------------------------------------

	fsm_control: process(rst, state, linecount, bb_wrreq, bb_rdreq, bb_clearfifo, colcount, fval, lval)
	begin

		state_next <= state;
		linecount_next <= linecount;

		bb_clearfifo_next <= bb_clearfifo;
		bb_wrreq_next <= bb_wrreq;
		bb_rdreq_next <= bb_rdreq;
		
		case state is
		when WAIT_INIT =>
			bb_clearfifo_next <= '1';
			bb_wrreq_next <= '0';
			bb_rdreq_next <= '0';
			
--			if init_old /= init_ready and init_ready = '1' then
--				state_next <= NOINIT;
--			end if;

		when NOINIT =>
			if fval = '0' then
				state_next <= WAITFRAME;
			end if;

		when WAITFRAME =>
			linecount_next <= (others => '0');
			
			if fval = '1' then
				bb_clearfifo_next <= '0';

				state_next <= WAITFIRST;
			end if;

		when WAITFIRST =>
			if lval = '1' then
				bb_wrreq_next <= '1';
				bb_rdreq_next <= '0';

				state_next <= FIRST;
			end if;

		when FIRST =>
			if lval = '0' then
				bb_wrreq_next <= '0';
				bb_rdreq_next <= '0';
				linecount_next <= linecount + '1';

				state_next <= WAITNORMAL;
			end if;

		when WAITNORMAL =>
			if lval = '1' then
				bb_wrreq_next <= '1';
				bb_rdreq_next <= '1';

				state_next <= NORMAL;
			end if;

		when NORMAL =>
			if lval = '0' then
				bb_wrreq_next <= '0';
				bb_rdreq_next <= '0';

				if linecount = conv_std_logic_vector(LASTLINE,10) then
					linecount_next <= (others => '0');
					state_next <= FRAMEEND;
				else
					linecount_next <= linecount + '1';
					state_next <= WAITNORMAL;
				end if;
			end if;

		when FRAMEEND =>
			bb_clearfifo_next <= '1';
			if fval = '0' then
				state_next <= WAITFRAME;
			end if;

		end case;

		if fval = '0' then
			bb_clearfifo_next <= '1';
			bb_wrreq_next <= '0';
			bb_rdreq_next <= '0';
			linecount_next <= (others => '0');
			state_next <= WAITFRAME;
		end if;
	end process;


	----------------------------------------------------------------------------
	-- Bayer converter
	----------------------------------------------------------------------------

	fsm : process(rst, state, pixelcount, linecount, colcount, dotmatrix, dpaddr, yResult, cbResult, crResult, yMin, yMax, cbMin, cbMax, crMin, crMax)
		variable green	: std_logic_vector(8 downto 0);
		variable red	: std_logic_vector(7 downto 0);
		variable blue	: std_logic_vector(7 downto 0);
		variable g1, g2	: std_logic_vector(8 downto 0);
		variable yVal, cbVal, crVal		: integer;
	begin
		-- defaults
		colcount_next <= colcount;
		pixelcount_next <= pixelcount;
		dpwren <= '0';
		dpaddr_next <= dpaddr;
		pixelburstReady_next <= '0';
		
		pixel <= (others => (others => '0'));

		filter_addr_next <= (others => '0');
		filter_data_next <= (others => '0');
		filter_we_next <= '0';
					
		yR <= (others => '0');
		cbR <= (others => '0');
		crR <= (others => '0');
		yG <= (others => '0');
		cbG <= (others => '0');
		crG <= (others => '0');
		yB <= (others => '0');
		cbB <= (others => '0');
		crB <= (others => '0');

		case state is
		when NORMAL =>
			colcount_next <= colcount + '1';

		when others =>
			dpaddr_next <= (others => '0');

			colcount_next <= (others => '0');
			pixelcount_next <= (others => '0');
		end case;

		if linecount > "0000000000" and colcount > "00000000001" and pixelcount < conv_std_logic_vector(LASTCOL,11) then
			-- Bayer pattern
			-- +----+----+----+----+----+----
			-- | G1 | R  | G1 | R  | G1 | ..
			-- +----+----+----+----+----+----
			-- | B  | G2 | B  | G2 | B  | ..
			-- +----+----+----+----+----+----
			-- | .. | .. | .. | .. | .. | ..
			-- +----+----+----+----+----+----

			pixelcount_next <= pixelcount + 1;

			if linecount(0) = '1' then
				if colcount(0) = '0' then
					g1 := "0" & dotmatrix(0)(0);
					g2 := "0" & dotmatrix(1)(1);
					red := dotmatrix(0)(1);
					blue := dotmatrix(1)(0);
					
					--pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
										
				else
					g1 := "0" & dotmatrix(0)(1);
					g2 := "0" & dotmatrix(1)(0);
					
					red := dotmatrix(0)(0);
					blue := dotmatrix(1)(1);
					--pixel <= (R => dotmatrix(0)(0), G => dotmatrix(0)(1), B => dotmatrix(1)(1));
					
				end if;
			else
				if colcount(0) = '0' then
					g1 := "0" & dotmatrix(1)(0);
					g2 := "0" & dotmatrix(0)(1);
					
					red := dotmatrix(1)(1);
					blue := dotmatrix(0)(0);
					--pixel <= (R => dotmatrix(1)(1), G => dotmatrix(1)(0), B => dotmatrix(0)(0));
				else
					g1 := "0" & dotmatrix(1)(1);
					g2 := "0" & dotmatrix(0)(0);
					
					red := dotmatrix(1)(0);
					blue := dotmatrix(0)(1);
					--pixel <= (R => dotmatrix(1)(0), G => dotmatrix(1)(1), B => dotmatrix(0)(1));
				end if;
			end if;
			
			green := std_logic_vector(unsigned(g1) + unsigned(g2));
			pixel(R) <= red;
			pixel(G) <= green(8 downto 1);
			pixel(B) <= blue;
					
			yR <= red;
			cbR <= red;
			crR <= red;
			yG <= green(8 downto 1);
			cbG <= green(8 downto 1);
			crG <= green(8 downto 1);
			yB <= blue;
			cbB <= blue;
			crB <= blue;

			-- convert to integer
			yVal := to_integer(signed(yResult(16 downto 8)));
			cbVal := to_integer(signed(cbResult(16 downto 8)));
			crVal := to_integer(signed(crResult(16 downto 8)));

			-- add offsets
			yVal := yVal + yOFFSET;
			cbVal := cbVal + cbOFFSET;
			crVal := crVal + crOFFSET;

			-- debug
			--yDBGV <= yResult(16 downto 8);
			--yDBG <= yVal;
			--cbDBGV <= cbResult(16 downto 8);
			--cbDBG <= cbVal;
			--crDBGV <= crResult(16 downto 8);
			--crDBG <= crVal;

			if (yVal > yMin and yVal < yMax)
				and (cbVal > cbMin and cbVal < cbMax)
				and (crVal > crMin and crVal < crMax)
			then
					pixel(SKIN) <= x"ff";
			end if;

			--pixel <= (R => dotmatrix(0)(1), G => green(8 downto 1), B => dotmatrix(1)(0));
			dpwren <= '1';
			dpaddr_next <= dpaddr + '1';

			if pixelcount(4 downto 0) = "11111" then
				pixelburstReady_next <= '1';
			end if;

			if pixelcount = conv_std_logic_vector(LASTCOL,11) then
				colcount_next <= (others => '0');
				pixelcount_next <= (others => '0');
			end if;

			filter_addr_next <= pixelcount(7 downto 0);
			filter_data_next <= green(8 downto 1);
			filter_we_next <= pixelcount(1);

		end if;
	end process;


	----------------------------------------------------------------------------
	-- Set registers
	----------------------------------------------------------------------------

	clk_reg : process(rst, clk)
	begin
		if rising_edge(clk) then
			bb_in_next <= pixdata(11 downto 4);
		end if;

		if falling_edge(clk) then
			state <= state_next;
			linecount <= linecount_next;
			colcount <= colcount_next;
			pixelcount <= pixelcount_next;
			pixelburstReady <= pixelburstReady_next;

			--init_old <= init_old_n;

			dotmatrix(1)(0) <= dotmatrix(1)(1);
			dotmatrix(1)(1) <= bb_out_next;
			dotmatrix(0)(0) <= dotmatrix(0)(1);
			dotmatrix(0)(1) <= bb_in;

			dpaddr <= dpaddr_next;
			dp_wren <= dpwren;
			dp_wraddr <= dpaddr;

			if output_mode = '0' then
				dp_data <= pixel(SKIN) & pixel(R) & pixel(G) & pixel(B);
			else
				dp_data <= pixel(SKIN) & pixel(SKIN) & pixel(SKIN) & pixel(SKIN);
			end if;


			bb_clearfifo <= bb_clearfifo_next;
			bb_wrreq <= bb_wrreq_next;
			bb_in <= bb_in_next;
			bb_rdreq <= bb_rdreq_next;

			filter_addr <= filter_addr_next;
			filter_data <= filter_data_next;
			filter_we <= filter_we_next;

		end if;

		if rst = '0' then
			--init_old <= '0';


			bb_clearfifo <= '1';
			bb_wrreq <= '0';
			bb_in <= (others => '0');
			bb_rdreq <= '0';


			linecount <= (others => '0');
			state <= NOINIT; --WAIT_INIT;
			colcount <= (others => '0');
			dotmatrix <= (others => (others => (others => '0')));
			pixelcount <= (others => '0');

			dpaddr <= (others => '0');

			filter_addr	<= (others => '0');
			filter_data	<= (others => '0');
			filter_we		<= '0';
		end if;
	end process;
end;


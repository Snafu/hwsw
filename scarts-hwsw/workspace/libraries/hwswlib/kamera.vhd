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

		init_ready			: in std_logic
    );
end ;

architecture rtl of kamera is
  
	constant MAXCOL			: integer := 802;
	constant LASTCOL			: integer := MAXCOL-2;
	constant MAXLINE			: integer := 482;
	constant LASTLINE			: integer := MAXLINE-2;
	
	constant yRed				: integer := 66;
	constant yGreen			: integer := 129;
	constant yBlue				: integer := 25;

	constant cbRed				: integer := -38;
	constant cbGreen			: integer := -74;
	constant cbBlue			: integer := 112;

	constant crRed				: integer := 112;
	constant crGreen			: integer := -94;
	constant crBlue			: integer := -18;
	
	constant yOFFSET			: integer := 16;
	constant cbOFFSET			: integer := 128;
	constant crOFFSET			: integer := 128;
	
	-- constants for SKIN color
	constant yMIN				: integer := 38;
	constant yMAX				: integer := 253;
	constant cbMIN				: integer := 94;
	constant cbMAX				: integer := 139;	
	constant crMIN				: integer := 139;
	constant crMAX				: integer := 173;
	
	
	--type state_t is (WAIT_INIT, NOINIT, WAITFRAME, WAITFIRST, FIRST, WAITNORMAL, NORMAL);
	type dotline_t is array (0 to 1) of std_logic_vector(7 downto 0);
	type dotmatrix_t is array (0 to 1) of dotline_t;
	type colors_t is (R, G, B);
	type pixel_t is array (colors_t'left to colors_t'right) of std_logic_vector(7 downto 0);

	signal init_old, init_old_n : std_logic := '0';

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
	signal bb_out_next							: std_logic_vector(7 downto 0);
	
	signal yR, yG, yB								: std_logic_vector(7 downto 0);
	signal yR_sig, yG_sig, yB_sig				: std_logic_vector(7 downto 0);
	signal yR_sig_n, yG_sig_n, yB_sig_n		: std_logic_vector(7 downto 0);
	signal yResult									: std_logic_vector(16 downto 0);
	
	signal cbR, cbG, cbB							: std_logic_vector(7 downto 0);
	signal cbR_sig, cbG_sig, cbB_sig			: std_logic_vector(7 downto 0);
	signal cbR_sig_n, cbG_sig_n, cbB_sig_n	: std_logic_vector(7 downto 0);
	signal cbResult								: std_logic_vector(16 downto 0);
	
	signal crR, crG, crB							: std_logic_vector(7 downto 0);
	signal crR_sig, crG_sig, crB_sig			: std_logic_vector(7 downto 0);
	signal crR_sig_n, crG_sig_n, crB_sig_n	: std_logic_vector(7 downto 0);
	signal crResult								: std_logic_vector(16 downto 0);
	

	signal filter_addr_next									: std_logic_vector(FILTERADDRLEN-1 downto 0);
	signal filter_data_next									: std_logic_vector(FILTERDATALEN-1 downto 0);
	signal filter_we_next										: std_logic;
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
		datab_0  => conv_std_logic_vector(yRed,9),
		datab_1  => conv_std_logic_vector(yGreen,9),
		datab_2  => conv_std_logic_vector(yBlue,9),
		result   => yResult
	);

--
	cbMUL : yCbCrMUL PORT MAP (
		clock0   => clk,
		dataa_0  => cbR,
		dataa_1  => cbG,
		dataa_2  => cbB,
		datab_0  => conv_std_logic_vector(cbRed,9),
		datab_1  => conv_std_logic_vector(cbGreen,9),
		datab_2  => conv_std_logic_vector(cbBlue,9),
		result   => cbResult
	);

	--
	crMUL : yCbCrMUL PORT MAP (
		clock0   => clk,
		dataa_0  => crR,
		dataa_1  => crG,
		dataa_2  => crB,
		datab_0  => conv_std_logic_vector(crRed,9),
		datab_1  => conv_std_logic_vector(crGreen,9),
		datab_2  => conv_std_logic_vector(crBlue,9),
		result   => crResult
	);

	
	
	camstate <= state;

	fsm_control: process(rst, state, linecount, bb_wrreq, bb_rdreq, bb_clearfifo, colcount, fval, lval, init_old, init_ready)
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
			
			if init_old /= init_ready and init_ready = '1' then
				state_next <= NOINIT;
			end if;

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

	fsm : process(rst, state, pixelcount, linecount, colcount, dotmatrix, dpaddr, yR_sig, yG_sig, yB_sig, cbR_sig, cbG_sig, cbB_sig, crR_sig, crG_sig, crB_sig)
		variable green	: std_logic_vector(8 downto 0);
		variable red	: std_logic_vector(7 downto 0);
		variable blue	: std_logic_vector(7 downto 0);
		variable g1, g2	: std_logic_vector(8 downto 0);
	begin
		-- defaults
		colcount_next <= colcount;
		pixelcount_next <= pixelcount;
		dpwren <= '0';
		dpaddr_next <= dpaddr;
		pixelburstReady_next <= '0';
		
		pixel <= (others => (others => '0'));
		
		yR_sig_n <= yR_sig;
		yG_sig_n <= yG_sig;
		yB_sig_n <= yB_sig;
			
		cbR_sig_n <= cbR_sig;
		cbG_sig_n <= cbG_sig;
		cbB_sig_n <= cbB_sig;
			
		crR_sig_n <= crR_sig;
		crG_sig_n <= crG_sig;
		crB_sig_n <= crB_sig;


		filter_addr_next <= (others => '0');
		filter_data_next <= (others => '0');
		filter_we_next <= '0';

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
					
					-- results from LAST cycle
					--if(( yResult > yMIN AND yResult < yMAX) AND (cbResult > cbMIN AND cbResult < cbMAX) AND (crResult > crMIN AND crResult < crMAX))
					if 1 < 3
					then
						--	skin color		-> white pixel
						null;
					else
						-- no skin color	-> black pixel
						null;
					end if;
					
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
					
			yR_sig_n <= red;
			yG_sig_n <= green(8 downto 1);
			yB_sig_n <= blue;
			
			cbR_sig_n <= red;
			cbG_sig_n <= green(8 downto 1);
			cbB_sig_n <= blue;
			
			crR_sig_n <= red;
			crG_sig_n <= green(8 downto 1);
			crB_sig_n <= blue;			

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

			init_old <= init_old_n;

			dotmatrix(1)(0) <= dotmatrix(1)(1);
			dotmatrix(1)(1) <= bb_out_next;
			dotmatrix(0)(0) <= dotmatrix(0)(1);
			dotmatrix(0)(1) <= bb_in;

			dpaddr <= dpaddr_next;
			dp_wren <= dpwren;
			dp_wraddr <= dpaddr;
			dp_data <= x"00" & pixel(R) & pixel(G) & pixel(B);


			bb_clearfifo <= bb_clearfifo_next;
			bb_wrreq <= bb_wrreq_next;
			bb_in <= bb_in_next;
			bb_rdreq <= bb_rdreq_next;
			
			yR_sig	<= yR_sig_n;
			yR			<= yR_sig_n;
			yG_sig	<= yG_sig_n;
			yG			<= yG_sig_n;
			yB_sig	<= yB_sig_n;
			yB			<= yB_sig_n;
			
			cbR_sig	<= cbR_sig_n;
			cbR		<= cbR_sig_n;
			cbG_sig	<= cbG_sig_n;
			cbG		<= cbG_sig_n;
			cbB_sig	<= cbB_sig_n;
			cbB		<= cbB_sig_n;
			
			crR_sig	<= crR_sig_n;
			crR		<= crR_sig_n;
			crG_sig	<= crG_sig_n;
			crG		<= crG_sig_n;
			crB_sig	<= crB_sig_n;
			crB		<= crB_sig_n;


			filter_addr <= filter_addr_next;
			filter_data <= filter_data_next;
			filter_we <= filter_we_next;

		end if;

		if rst = '0' then
			init_old <= '0';


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
		end if;
	end process;
end;


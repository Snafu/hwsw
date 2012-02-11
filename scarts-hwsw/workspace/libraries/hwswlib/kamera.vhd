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

library grlib;
use grlib.stdlib.all;


library work;
use work.kameralib.all;
use work.bayerbuf.all;


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
		
		dp_data			: out std_logic_vector(31 downto 0);
		dp_wren			: out std_logic;
		dp_wraddr		: out std_logic_vector(8 downto 0);
		
		pixelburstReady	: out std_logic;
		
		whichLine_dbg	: out std_logic;
		burstCount_dbg	: out std_logic_vector(4 downto 0)
    );
end ;

architecture rtl of kamera is
  
  constant PIXELBURSTLEN		: integer := 15;
	constant LASTBLINE				: integer := 478;
	type state_t is (NOINIT, WAITFRAME, WAITFIRST, FIRST, WAITBLINE, BLINE, WAITLAST, LAST);
	type dotline_t is array (0 to 1) of std_logic_vector(7 downto 0);
	type dotmatrix_t is array (0 to 1) of dotline_t;
	type colors_t is (R, G, B);
	type pixel_t is array (colors_t'left to colors_t'right) of std_logic_vector(7 downto 0);

	signal dot, dot_next, dot_nnext			: std_logic_vector(7 downto 0);
	signal lastdot, lastdot_next				: std_logic_vector(7 downto 0);
	signal state, state_next						: state_t;
	signal rdreq, rdreq_next						: std_logic := '0';
	signal startconv										: std_logic;
	signal linecount, linecount_next		: integer range 0 to 480;
	signal colcount, colcount_next			: std_logic_vector(9 downto 0);
	signal pixelcount, pixelcount_next	: integer range 0 to 800;
	signal nfval												: std_logic;
	signal pixel, pixel_next						: pixel_t;
	signal dotmatrix, dotmatrix_next		: dotmatrix_t;
	signal wren													: std_logic;
begin

	nfval <= not fval;
	
	bayerbuf : bayerbuffer PORT MAP (
		clock	 => pixclk,
		data	 => pixdata(11 downto 4),
		rdreq	 => rdreq,
		sclr => nfval,
		q	 => lastdot_next,
		wrreq	 => lval 
	);

	fsm_control: process(rst, state, linecount, colcount, fval, lval, rdreq)
	begin

		state_next <= state;
		linecount_next <= linecount;
		rdreq_next <= rdreq;
		
		case state is
		when NOINIT =>
			if fval = '0' then
				state_next <= WAITFRAME;
			end if;

		when WAITFRAME =>
			if fval = '1' then
				linecount_next <= 0;
				state_next <= WAITFIRST;
			end if;

		when WAITFIRST =>
			if lval = '1' then
				rdreq_next <= '0';
				state_next <= FIRST;
			end if;

		when FIRST =>
			if lval = '0' then
				linecount_next <= linecount + 1;
				rdreq_next <= '0';
				state_next <= WAITBLINE;
			end if;

		when WAITBLINE =>
			if lval = '1' then
				rdreq_next <= '1';
				state_next <= BLINE;
			end if;

		when BLINE =>
			if lval = '0' then
				linecount_next <= linecount + 1;
				rdreq_next <= '0';
				if linecount = LASTBLINE then
					state_next <= WAITLAST;
				else
					state_next <= WAITBLINE;
				end if;
			end if;

		when WAITLAST =>
			if lval = '1' then
				rdreq_next <= '1';
				state_next <= LAST;
			end if;

		when LAST =>
			if lval = '0' then
				linecount_next <= 0;
				rdreq_next <= '0';
				state_next <= WAITFIRST;
			end if;

		end case;

		if fval = '0' then
			state_next <= WAITFRAME;
		end if;
	end process;

	fsm : process(state, rdreq, lastdot, lastdot_next, dot, dot_next, linecount, colcount)
	begin
		colcount_next <= colcount;
		dotmatrix_next <= dotmatrix;
		pixel_next <= pixel;
		pixelcount_next <= pixelcount;
		wren <= '0';

		if rdreq = '1' or pixelcount > 0 then
			wren <= '1';
			colcount_next <= colcount + '1';
			dotmatrix_next(0)(0) <= dotmatrix(0)(1);
			dotmatrix_next(0)(1) <= lastdot_next;
			dotmatrix_next(1)(0) <= dotmatrix(1)(1);
			dotmatrix_next(1)(1) <= dot_next;

			if colcount(0) = '0' then
				pixel_next <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
			else
				pixel_next <= (R => dotmatrix(0)(0), G => dotmatrix(0)(1), B => dotmatrix(1)(1));
			end if;

			pixelcount_next <= pixelcount + 1;
			if pixelcount = 798 then
				pixelcount_next <= 0;
			end if;

			if colcount < '0' & x"00000003" then
				pixel_next <= (others => (others => '0'));
				pixelcount_next <= 0;
				wren <= '0';
			end if;
		end if;
	end process;


	pixclk_reg : process(rst, pixclk)
	begin
		if rst = '0' then
			dot <= (others => '0');
			linecount <= 0;
			rdreq <= '0';
			startconv <= '0';
			state <= NOINIT;
			lastdot <= (others => '0');
			colcount <= (others => '0');
			pixel <= (others => (others => '0'));
			dotmatrix <= (others => (others => (others => '0')));
			pixelcount <= 0;
		else
			if rising_edge(pixclk) then
				dot_nnext <= pixdata(11 downto 4);
				dot_next <= dot_nnext;
			end if;

			if falling_edge(pixclk) then
				linecount <= linecount_next;
				dot <= dot_next;
				lastdot <= lastdot_next;
				colcount <= colcount_next;
				state <= state_next;
				rdreq <= rdreq_next;
				startconv <= rdreq;
				pixel <= pixel_next;
				dotmatrix <= dotmatrix_next;
				pixelcount <= pixelcount_next;
				dp_wren <= wren;
				dp_wraddr <= conv_std_logic_vector(pixelcount,9);
				dp_data <= x"00" & pixel_next(R) & pixel_next(G) & pixel_next(B);
			end if;
		end if;
	end process;
end;


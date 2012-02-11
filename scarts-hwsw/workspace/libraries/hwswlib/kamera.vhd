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
	signal linecount, linecount_next		: integer range 0 to 480;
	signal colcount, colcount_next			: std_logic_vector(9 downto 0);
	signal pixelcount, pixelcount_next	: std_logic_vector(9 downto 0);
	signal nfval												: std_logic;
	signal pixel												: pixel_t;
	signal dotmatrix, dotmatrix_next		: dotmatrix_t;
	signal convert											: std_logic;
	signal dpwren												: std_logic;
	signal dpaddr, dpaddr_next					: std_logic_vector(8 downto 0);
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

	fsm : process(rst, convert, pixelcount, linecount, colcount)
	begin
		-- defaults
		colcount_next <= colcount;
		pixelcount_next <= pixelcount;
		dpwren <= '0';
		dpaddr_next <= dpaddr;
		pixel <= (others => (others => '0'));
		pixelburstReady <= '0';
		

		if convert = '0' then
			colcount_next <= (others => '0');
		else
			colcount_next <= colcount + '1';
			if colcount = conv_std_logic_vector(800,10) then
				colcount_next <= (others => '0');
			end if;

			pixelcount_next <= pixelcount + 1;
			if pixelcount = conv_std_logic_vector(799,10) then
				pixelcount_next <= (others => '0');
			end if;

			-- interpolate pixels TODO: average g1 and g2
			if colcount(1) = '0' then
				pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
			else
				pixel <= (R => dotmatrix(0)(0), G => dotmatrix(0)(1), B => dotmatrix(1)(1));
			end if;

			dpwren <= '1';
			dpaddr_next <= dpaddr + '1';

			-- delay pixel counter until first pixel ready
			if colcount < "0000000010" then
				pixelcount_next <= (others => '0');
			else
			end if;

			-- delay DP RAM write until first pixel ready
			if colcount < "0000000001" then
				pixel <= (others => (others => '0'));
				dpwren <= '0';
				dpaddr_next <= dpaddr;
			end if;
				-- signal block ready
				if (pixelcount(3 downto 0) = "0000" and pixelcount /= "0000000000")
					or pixelcount = conv_std_logic_vector(798, 10) then
					pixelburstReady <= '1';
				end if;

		end if;
	end process;


	pixclk_reg : process(rst, pixclk)
	begin
		if rst = '0' then
			dot <= (others => '0');
			linecount <= 0;
			rdreq <= '0';
			state <= NOINIT;
			lastdot <= (others => '0');
			colcount <= (others => '0');
			dotmatrix <= (others => (others => (others => '0')));
			pixelcount <= (others => '0');
			convert <= '0';

			dpaddr <= (others => '1');
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
				dotmatrix <= dotmatrix_next;
				pixelcount <= pixelcount_next;
				convert <= rdreq;

				dpaddr <= dpaddr_next;
				dp_wren <= dpwren;
				dp_wraddr <= dpaddr_next;
				dp_data <= x"00" & pixel(R) & pixel(G) & pixel(B);

				dotmatrix(0)(0) <= dotmatrix(0)(1);
				dotmatrix(0)(1) <= lastdot_next;
				dotmatrix(1)(0) <= dotmatrix(1)(1);
				dotmatrix(1)(1) <= dot_next;
			end if;
		end if;
	end process;
end;


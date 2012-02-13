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

	port (
		camstate				: out state_t; --dbg
		rst							: in std_logic;	-- Synchronous reset
		clk							: in std_logic;
		pixclk					: in std_logic;
		fval						: in std_logic;
		lval						: in std_logic;
		pixdata					: in std_logic_vector(11 downto 0);
		
		dp_data					: out std_logic_vector(31 downto 0);
		dp_wren					: out std_logic;
		dp_wraddr				: out std_logic_vector(8 downto 0);
		
		pixelburstReady	: out std_logic;

		init_ready			: in std_logic
    );
end ;

architecture rtl of kamera is
  
  constant PIXELBURSTLEN		: integer := 15;
	constant MAXLINE					: integer := 481;
	constant MAXCOL						: integer := 801;
	constant LASTBLINE				: integer := MAXLINE-2;

	--type state_t is (WAIT_INIT, NOINIT, WAITFRAME, WAITFIRST, FIRST, WAITNORMAL, NORMAL);
	type dotline_t is array (0 to 1) of std_logic_vector(7 downto 0);
	type dotmatrix_t is array (0 to 1) of dotline_t;
	type colors_t is (R, G, B);
	type pixel_t is array (colors_t'left to colors_t'right) of std_logic_vector(7 downto 0);

	signal init_old, init_old_n : std_logic := '0';

	signal dot, dot_next								: std_logic_vector(7 downto 0);
	signal lastdot											: std_logic_vector(7 downto 0);
	signal state, state_next						: state_t;
	signal linecount, linecount_next		: std_logic_vector(8 downto 0);
	signal colcount, colcount_next			: std_logic_vector(9 downto 0);
	signal pixelcount, pixelcount_next	: std_logic_vector(9 downto 0);
	signal clearfifo										: std_logic;
	signal rdreq, rdreq_next						: std_logic := '0';
	signal wrreq												: std_logic := '0';
	signal pixel												: pixel_t;
	signal dotmatrix										: dotmatrix_t;
	signal convert, convert_old					: std_logic;
	signal dpwren												: std_logic;
	signal dpaddr, dpaddr_next					: std_logic_vector(8 downto 0);
begin

	bayerbuf : bayerbuffer PORT MAP (
		clock	 	=> pixclk,
		data	 	=> pixdata(11 downto 4),
		rdreq	 	=> rdreq,
		sclr	 	=> clearfifo,
		q				=> lastdot,
		wrreq		=> wrreq 
	);

	camstate <= state;

	fsm_control: process(rst, state, linecount, colcount, fval, lval, init_old, init_ready)
	begin

		state_next <= state;
		linecount_next <= linecount;

		clearfifo <= not fval;
		wrreq <= lval;
		rdreq_next <= lval;

		if rst = '0' then
			wrreq <= '0';
			rdreq_next <= '0';
			clearfifo <= '1';
		end if;

		
		case state is
		when WAIT_INIT =>
			clearfifo <= '1';
			wrreq <= '0';
			rdreq_next <= '0';

			if init_old /= init_ready and init_ready = '1' then
				state_next <= NOINIT;
			end if;

		when NOINIT =>
			clearfifo <= '1';
			wrreq <= '0';
			rdreq_next <= '0';

			if fval = '0' then
				state_next <= WAITFRAME;
			end if;

		when WAITFRAME =>
			rdreq_next <= '0';
			wrreq <= '0';
			linecount_next <= (others => '0');
			if fval = '1' then
				state_next <= WAITFIRST;
			end if;

		when WAITFIRST =>
			rdreq_next <= '0';
			if lval = '1' then
				state_next <= FIRST;
			end if;

		when FIRST =>
			rdreq_next <= '0';
			if lval = '0' then
				linecount_next <= linecount + '1';
				state_next <= WAITNORMAL;
			end if;

		when WAITNORMAL =>
			if lval = '1' then
				state_next <= NORMAL;
			end if;

		when NORMAL =>
			if lval = '0' then
				if linecount = conv_std_logic_vector(LASTBLINE,9) then
					linecount_next <= (others => '0');
					state_next <= WAITFRAME;
				else
					linecount_next <= linecount + '1';
					state_next <= WAITNORMAL;
				end if;
			end if;

		end case;

		if fval = '0' then
			rdreq_next <= '0';
			wrreq <= '0';
			state_next <= WAITFRAME;
		end if;
	end process;

	fsm : process(rst, state, convert, pixelcount, linecount, colcount, dotmatrix, dpaddr)
	begin
		-- defaults
		colcount_next <= colcount;
		pixelcount_next <= pixelcount;
		dpwren <= '0';
		dpaddr_next <= dpaddr;
		pixel <= (others => (others => '0'));
		pixelburstReady <= '0';
		
		if state /= WAIT_INIT and state /= NOINIT then
			if convert = '0' then
				colcount_next <= (others => '0');
				pixelcount_next <= (others => '0');
				dpaddr_next <= (others => '0');
				-- signal last block ready
				--if pixelcount = conv_std_logic_vector(MAXCOL-2,10) then
				if convert_old = '1' then
					pixelburstReady <= '1';
				end if;
			else
				colcount_next <= colcount + '1';
				if colcount = conv_std_logic_vector(MAXCOL-1,10) then
					colcount_next <= (others => '0');
				end if;
	
				-- last pixel (one less than last col)
				pixelcount_next <= pixelcount + 1;
	
				-- interpolate pixels TODO: average g1 and g2
				if colcount(0) = '0' then
					pixel <= (R => dotmatrix(0)(0), G => dotmatrix(0)(1), B => dotmatrix(1)(1));
				else
					pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
				end if;
	
				dpwren <= '1';
				dpaddr_next <= dpaddr + '1';
	
				-- delay until first pixel ready
				if colcount < "0000000010" then
					pixelcount_next <= (others => '0');
					dpaddr_next <= (others => '0');
				end if;
	
				-- delay DP RAM write until first pixel ready
				if colcount < "0000000001" then
					pixel <= (others => (others => '0'));
					dpwren <= '0';
				end if;
	
				-- signal block ready
				if pixelcount(4 downto 0) = "00000" and pixelcount /= "0000000000" then
					pixelburstReady <= '1';
				end if;
	
			end if;
		end if;
	end process;


	clk_reg : process(rst, clk)
	begin
		if rst = '0' then
			init_old <= '0';
		else
			init_old <= init_old_n;
		end if;
	end process;


	pixclk_reg : process(rst, pixclk)
	begin
		if rst = '0' then
			linecount <= (others => '0');
			rdreq <= '0';
			state <= WAIT_INIT;
			dot <= (others => '0');
			colcount <= (others => '0');
			dotmatrix <= (others => (others => (others => '0')));
			pixelcount <= (others => '0');
			convert <= '0';
			convert_old <= '0';

			dpaddr <= (others => '0');
		else
			if rising_edge(pixclk) then
				dot_next <= pixdata(11 downto 4);
				dot <= dot_next;
			end if;

			if falling_edge(pixclk) then
				linecount <= linecount_next;
				colcount <= colcount_next;
				state <= state_next;
				rdreq <= rdreq_next;
				pixelcount <= pixelcount_next;
				convert <= rdreq;
				convert_old <= convert;

				dpaddr <= dpaddr_next;
				dp_wren <= dpwren;
				dp_wraddr <= dpaddr_next;
				dp_data <= x"00" & pixel(R) & pixel(G) & pixel(B);

				dotmatrix(0)(1) <= dotmatrix(0)(0);
				dotmatrix(0)(0) <= lastdot;
				dotmatrix(1)(1) <= dotmatrix(1)(0);
				dotmatrix(1)(0) <= dot;
			end if;
		end if;
	end process;
end;


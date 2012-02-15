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

	port (
		camstate				: out state_t; --dbg
		rst							: in std_logic;	-- Synchronous reset
		clk							: in std_logic;
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
  
	constant MAXCOL						: integer := 1600;
	constant LASTCOL					: integer := MAXCOL-1;
	constant MAXLINE					: integer := 960;
	constant LASTLINE					: integer := MAXLINE-1;

	--type state_t is (WAIT_INIT, NOINIT, WAITFRAME, WAITFIRST, FIRST, WAITNORMAL, NORMAL);
	type dotline_t is array (0 to 1) of std_logic_vector(7 downto 0);
	type dotmatrix_t is array (0 to 1) of dotline_t;
	type colors_t is (R, G, B);
	type pixel_t is array (colors_t'left to colors_t'right) of std_logic_vector(7 downto 0);

	signal init_old, init_old_n : std_logic := '0';

	signal dot													: std_logic_vector(7 downto 0);
	signal lastdot											: std_logic_vector(7 downto 0);
	signal state, state_next						: state_t;
	signal linecount, linecount_next		: std_logic_vector(9 downto 0);
	signal colcount, colcount_next			: std_logic_vector(10 downto 0);
	signal pixelcount, pixelcount_next	: std_logic_vector(10 downto 0);
	signal clearfifo										: std_logic;
	signal rdreq, rdreq_next						: std_logic := '0';
	signal wrreq, wrreq_next						: std_logic := '0';
	signal pixel												: pixel_t;
	signal dotmatrix										: dotmatrix_t;
	signal inline, inline_next					: std_logic;
	signal dpwren												: std_logic;
	signal dpaddr, dpaddr_next					: std_logic_vector(8 downto 0);

	signal pixelburstReady_next					: std_logic;
begin

	bayerbuf : bayerbuffer PORT MAP (
		clock	 	=> clk,
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
		wrreq <= '0';
		rdreq <= '0';
		
		case state is
		when WAIT_INIT =>
			clearfifo <= '1';

			if init_old /= init_ready and init_ready = '1' then
				state_next <= NOINIT;
			end if;

		when NOINIT =>
			clearfifo <= '1';

			if fval = '0' then
				state_next <= WAITFRAME;
			end if;

		when WAITFRAME =>
			linecount_next <= (others => '0');
			
			if fval = '1' then
				state_next <= WAITFIRST;
			end if;

		when WAITFIRST =>
			wrreq <= lval;
			
			if lval = '1' then
				state_next <= FIRST;
			end if;

		when FIRST =>
			wrreq <= lval;

			if lval = '0' then
				linecount_next <= linecount + '1';
				state_next <= WAITNORMAL;
			end if;

		when WAITNORMAL =>
			rdreq <= lval;

			if lval = '1' then
				state_next <= NORMAL;
			end if;

		when NORMAL =>
			rdreq <= lval;

			if lval = '0' then
				if linecount = conv_std_logic_vector(LASTLINE,10) then
					rdreq <= '0';
					linecount_next <= (others => '0');
					state_next <= WAITFRAME;
				else
					linecount_next <= linecount + '1';
					state_next <= WAITFIRST;
				end if;
			end if;

		end case;

		if fval = '0' then
			clearfifo <= '1';
			wrreq <= '0';
			rdreq <= '0';
			linecount_next <= (others => '0');
			state_next <= WAITFRAME;
		end if;
	end process;

	fsm : process(rst, state, inline, pixelcount, linecount, colcount, dotmatrix, dpaddr)
		variable green	: std_logic_vector(8 downto 0);
		variable g1, g2	: std_logic_vector(8 downto 0);
	begin
		-- defaults
		colcount_next <= colcount;
		pixelcount_next <= pixelcount;
		dpwren <= '0';
		dpaddr_next <= dpaddr;
		pixel <= (others => (others => '0'));
		pixelburstReady_next <= '0';

		if inline = '1' and (state = NORMAL or state = WAITFIRST or state = WAITFRAME) then
			colcount_next <= colcount + '1';
			if colcount = conv_std_logic_vector(LASTCOL,11) then
				colcount_next <= (others => '0');
			end if;

			-- interpolate pixels TODO: average g1 and g2
			if pixelcount < conv_std_logic_vector(LASTCOL,11) then
				-- Bayer pattern
				-- +----+----+----+----+----+----
				-- | G1 | R  | G1 | R  | G1 | ..
				-- +----+----+----+----+----+----
				-- | B  | G2 | B  | G2 | B  | ..
				-- +----+----+----+----+----+----
				-- | .. | .. | .. | .. | .. | ..
				-- +----+----+----+----+----+----

--				if colcount(0) = '0' then
--					g1 := "0" & dotmatrix(0)(0);
--					g2 := "0" & dotmatrix(1)(1);
--					green := std_logic_vector(unsigned(g1) + unsigned(g2));
--					--pixel <= (R => dotmatrix(0)(1), G => green(8 downto 1), B => dotmatrix(1)(0));
--					pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
--				else
--					g1 := "0" & dotmatrix(0)(1);
--					g2 := "0" & dotmatrix(1)(0);
--					green := std_logic_vector(unsigned(g1) + unsigned(g2));
--					--pixel <= (R => dotmatrix(0)(0), G => green(8 downto 1), B => dotmatrix(1)(1));
--					pixel <= (R => dotmatrix(0)(0), G => dotmatrix(0)(1), B => dotmatrix(1)(1));
--				end if;
				if colcount(0) = '0' then
					pixelcount_next <= pixelcount + 1;

					--pixel <= (R => dotmatrix(0)(1), G => x"00", B => x"00");
					pixel <= (R => x"00", G => dotmatrix(0)(0), B => x"00");
					--pixel <= (R => x"00", G => x"00", B => dotmatrix(1)(0));

					--pixel <= (R => x"00", G => dotmatrix(0)(0), B => dotmatrix(1)(0));
					--pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => x"00");

					--pixel <= (R => dotmatrix(0)(1), G => dotmatrix(0)(0), B => dotmatrix(1)(0));
					dpwren <= '1';
					dpaddr_next <= dpaddr + '1';
				end if;

			end if;

			-- signal block ready
			if pixelcount(4 downto 0) = "00000" and pixelcount /= "00000000000" then
				pixelburstReady_next <= '1';
			end if;

		end if;
		
		if inline = '0' then
			colcount_next <= (others => '0');
			pixelcount_next <= (others => '0');
			dpaddr_next <= (others => '0');
		end if;
	end process;

	clk_reg : process(rst, clk)
	begin
		if rising_edge(clk) then
			dot <= pixdata(11 downto 4);
		end if;

		if falling_edge(clk) then
			state <= state_next;
			linecount <= linecount_next;
			colcount <= colcount_next;
			pixelcount <= pixelcount_next;
			pixelburstReady <= pixelburstReady_next;

			init_old <= init_old_n;
			inline_next <= rdreq;
			inline <= inline_next;

			dotmatrix(1)(0) <= dotmatrix(0)(1);
			dotmatrix(1)(1) <= lastdot;
			dotmatrix(0)(0) <= dotmatrix(1)(1);
			dotmatrix(0)(1) <= dot;

			dpaddr <= dpaddr_next;
			dp_wren <= dpwren;
			dp_wraddr <= dpaddr;
			dp_data <= x"00" & pixel(R) & pixel(G) & pixel(B);
		end if;

		if rst = '0' then
			init_old <= '0';


			linecount <= (others => '0');
			state <= NOINIT; --WAIT_INIT;
			dot <= (others => '0');
			colcount <= (others => '0');
			dotmatrix <= (others => (others => (others => '0')));
			pixelcount <= (others => '0');
			inline <= '0';

			dpaddr <= (others => '0');
		end if;
	end process;
end;


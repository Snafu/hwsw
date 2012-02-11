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

	signal fval_l											: std_logic;
	signal lval_l											: std_logic;
	signal dot, dot_next							: std_logic_vector(7 downto 0);
	signal lastdot, lastdot_next			: std_logic_vector(7 downto 0);
	signal state, state_next					: state_t;
	signal rdreq, rdreq_next					: std_logic := '0';
	signal wrreq, wrreq_next					: std_logic := '0';
	signal linecount, linecount_next	: integer range 0 to 480;
	signal colcount, colcount_next		: integer range 0 to 480;
begin
	
	bayerbuf : bayerbuffer PORT MAP (
		clock	 => pixclk,
		data	 => dot,
		rdreq	 => rdreq,
		wrreq	 => wrreq,
		q	 => lastdot
	);

	fsm_control: process(rst, state, linecount, colcount, fval, lval, wrreq, rdreq)
	begin

		state_next <= state;
		linecount_next <= linecount;
		wrreq_next <= wrreq;
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
				wrreq_next <= '1';
				rdreq_next <= '0';
				state_next <= FIRST;
			end if;

		when FIRST =>
			if lval = '0' then
				linecount_next <= linecount + 1;
				wrreq_next <= '0';
				rdreq_next <= '0';
				state_next <= WAITBLINE;
			end if;

		when WAITBLINE =>
			if lval = '1' then
				wrreq_next <= '1';
				rdreq_next <= '1';
				state_next <= BLINE;
			end if;

		when BLINE =>
			if lval = '0' then
				linecount_next <= linecount + 1;
				wrreq_next <= '0';
				rdreq_next <= '0';
				if linecount = LASTBLINE then
					state_next <= WAITLAST;
				else
					state_next <= WAITBLINE;
				end if;
			end if;

		when WAITLAST =>
			if lval = '1' then
				wrreq_next <= '0';
				rdreq_next <= '1';
				state_next <= LAST;
			end if;

		when LAST =>
			if lval = '0' then
				linecount_next <= 0;
				wrreq_next <= '0';
				rdreq_next <= '0';
				state_next <= WAITFIRST;
			end if;

		end case;

		if fval = '0' then
			state_next <= WAITFRAME;
		end if;
	end process;

	fsm : process(state, dot, linecount, colcount)
	begin
		
	end process;


	pixclk_reg : process(rst, pixclk)
	begin
		if rst = '0' then
			fval_l <= '0';
			lval_l <= '0';
			dot <= (others => '0');
			linecount <= 0;
			rdreq <= '0';
			wrreq <= '0';
			state <= NOINIT;
		else
			if rising_edge(pixclk) then
				dot_next <= pixdata(11 downto 4);
			end if;

			if falling_edge(pixclk) then
				fval_l <= fval;
				lval_l <= lval;
				linecount <= linecount_next;
				dot <= dot_next;
				state <= state_next;
				rdreq <= rdreq_next;
				wrreq <= wrreq_next;
			end if;
		end if;
	end process;
end;


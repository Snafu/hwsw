-----------------------------------------------------------------------------
-- Entity:      dispctrl
-- File:        dispctrl.vhd
-- Author:      Christopher Gabriel
-- Modified:    
-- Contact:     stuff@c-gabriel.at
-- Description: Display data controller
-----------------------------------------------------------------------------
-- GRLIB2 CORE
-- VENDOR:      VENDOR_HWSW
-- DEVICE:      HWSW_DISPCTRL
-- VERSION:     0
-- AHBMASTER:   0
-- APB:         0
-- BAR: 0       TYPE: 0010      PREFETCH: 0     CACHE: 0        DESC: IO_AREA
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library gaisler;
use gaisler.misc.all;

library hwswlib;
use work.hwswlib.all;
 
 
entity dispctrl is

  generic(
    hindex      : integer := 0;
    hirq        : integer := 0;
    ahbaccsz    : integer := 32
    );
  
  port (
		ahbready_dbg	: out std_logic;
    rst     	  	: in std_logic;           -- Synchronous reset
    clk     	  	: in std_logic;
    ahbi					: in  ahb_mst_in_type;
    ahbo					: out ahb_mst_out_type;
		fval					: in std_logic;
		rdaddress 		: out std_logic_vector(8 downto 0);
		rddata    		: in std_logic_vector(31 downto 0);
		blockrdy  		: in std_logic;
	
		init_ready		: in std_logic
    );

end ;

architecture rtl of dispctrl is
  
	constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0000000";
	constant FIFOEND : std_logic_vector(31 downto 0) := x"E00BB800"; --dbg
	--constant FIFOEND : std_logic_vector(31 downto 0) := x"E0177000";
	
	constant NOFACE : std_logic_vector(9 downto 0) := "1111111111";
	constant COLORA : std_logic_vector(31 downto 0) := x"00FF0000";
	constant COLORB : std_logic_vector(31 downto 0) := x"0000FF00";
	constant COLORC : std_logic_vector(31 downto 0) := x"000000FF";
	constant COLORD : std_logic_vector(31 downto 0) := x"00FFFFFF";
	constant MAXCOL : integer := 400;
	constant MAXROW : integer := 240;

  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;
    
	type facebox_t is record
		top					: std_logic_vector(9 downto 0);
		left				: std_logic_vector(9 downto 0);
		bottom			: std_logic_vector(9 downto 0);
		right				: std_logic_vector(9 downto 0);
	end record;

  type write_t is record
		address 	: std_logic_vector(31 downto 0);
		data			: std_logic_vector(31 downto 0);
  end record;
	
	type writestate_t is (WAIT_INIT, NOINIT,IDLE,STARTBLOCK,RESTART,WAITREADY,HANDLEBLOCK,FINISHBLOCK,UPDATEDPADDR);

  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;
	
	signal writeState, writeState_n : writestate_t := WAIT_INIT;
	--signal writeState, writeState_n : writestate_t := NOINIT;
	signal fval_old, fval_old_n : std_logic := '0';
	signal init_old, init_old_n : std_logic := '0';
	signal blockrdy_old, blockrdy_old_n : std_logic;
	signal blockCount, blockCount_n : integer range 0 to 1023;
	signal output, output_n : write_t;
	signal pixeladdr, pixeladdr_n : std_logic_vector(8 downto 0) := "000000000";
begin

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW, HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);
  
  control_proc : process(rst,ahbi,dmai,dmao,fval,fval_old,blockrdy,writeState,pixeladdr,rddata,blockCount,output,blockrdy_old,init_ready,init_old)
		variable wout : write_t;
		variable ahbready : std_logic;
		variable start : std_logic;
		variable blocks : integer range 0 to 1023;
  begin

		writeState_n <= writeState;
		fval_old_n <= fval;
		blockrdy_old_n <= blockrdy;
		blocks := blockCount;
		pixeladdr_n <= pixeladdr;
		wout := output;
		start := '0';
		ahbready := dmao.ready;
		init_old_n <= init_ready;

		ahbready_dbg <= ahbready;

		if rst = '1' and blockrdy_old /= blockrdy and blockrdy = '1' then
			blocks := blocks + 1;
		end if;

		case writeState is
		
		-- wait for i2c - initialization, signaled by extension module
		when WAIT_INIT =>
			if  init_old /= init_ready and init_ready = '1' then
				writeState_n <= NOINIT;
			end if;
			
		when NOINIT =>
			if rst = '1' and fval_old /= fval and fval = '1' then
				writeState_n <= IDLE;
				blockCount_n <= 0;
				wout.address := FIFOSTART;
				pixeladdr_n <= "000000000";
			end if;

		when IDLE =>
			if blocks > 0 then --dbg
				writeState_n <= STARTBLOCK;
			end if;

		when STARTBLOCK =>
			wout.data := rddata;

			writeState_n <= HANDLEBLOCK;

		when RESTART =>
			start := '1';

			writeState_n <= HANDLEBLOCK;

		when HANDLEBLOCK =>
			start := '1';
			if ahbready = '1' then
				wout.data := rddata;
				wout.address := output.address + 4;
				pixeladdr_n <= pixeladdr + '1';

				-- end of block
				if wout.address(5 downto 2) = "0000" then
					blocks := blocks - 1;

					writeState_n <= IDLE;
				end if;
			end if;

		when others =>
		end case;

		if pixeladdr = conv_std_logic_vector(510,9) then
			pixeladdr_n <= "000000000";
			--wout.address := wout.address + x"640";
		end if;

		-- stay within framebuffer
		if wout.address >= FIFOEND then
			wout.address := FIFOSTART;
			pixeladdr_n <= "000000000";
		end if;
		
		output_n <= wout;
		blockCount_n <= blocks;
		rdaddress <= pixeladdr;
		
		
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		dmai.wdata <= output.data;
		dmai.address <= output.address;
		dmai.start <= start;

		--if ((output.rowcnt = output.face.top or output.rowcnt = output.face.bottom)
		--		and (output.colcnt >= output.face.left and output.colcnt <= output.face.right))
		--	 or
		--	 ((output.colcnt = output.face.left or output.colcnt = output.face.right)
		--	  and (output.rowcnt >= output.face.top and output.rowcnt <= output.face.bottom)) then
		--	dmai.wdata <= x"0000ff00";
		--else
		--	dmai.wdata <= output.data;
		--end if;
			
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(rst,clk)
  begin
    if rising_edge(clk) then
			if rst = '0' then
				writeState <= WAIT_INIT;
				fval_old <= '0';
				blockrdy_old <= '0';
				blockCount <= 0;
				output.address <= FIFOSTART;
				output.data <= x"00FFFFFF";
				init_old <= '0';
			else
				writeState <= writeState_n;
				fval_old <= fval_old_n;
				blockrdy_old <= blockrdy_old_n;
				blockCount <= blockCount_n;
				output <= output_n;
				
				init_old <= init_old_n;
			end if;
    elsif falling_edge(clk) then
			if rst = '0' then
				pixeladdr <= "000000000";
			else
				pixeladdr <= pixeladdr_n;
			end if;
		end if;
  end process;
end;


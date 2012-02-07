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
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.misc.all;

library hwswlib;
use work.hwswlib.all;
 
 
entity dispctrl is

  generic(
    pindex      : integer := 0;
    paddr       : integer := 0;
    pmask       : integer := 16#fff#;
    hindex      : integer := 0;
    hirq        : integer := 0;
    ahbaccsz    : integer := 32
    );
  
  port (
    rst       : in std_logic;           -- Synchronous reset
    clk       : in std_logic;
    apbi      : in apb_slv_in_type;
    apbo      : out apb_slv_out_type;
    ahbi      : in  ahb_mst_in_type;
    ahbo      : out ahb_mst_out_type;
		fval			: in std_logic;
		rdaddress : out std_logic_vector(8 downto 0);
		rddata    : in std_logic_vector(31 downto 0);
		blockrdy  : in std_logic
    );

end ;

architecture rtl of dispctrl is
  
	constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0000000";
	--constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0173180";
	constant FIFOEND : std_logic_vector(31 downto 0) := x"E0177000";
	constant NOFACE : std_logic_vector(9 downto 0) := "1111111111";
	constant COLORA : std_logic_vector(31 downto 0) := x"00CC0000";
	constant COLORB : std_logic_vector(31 downto 0) := x"0000CC00";
	constant MAXCOL : integer := 401;
	constant MAXROW : integer := 240;

  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    
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
	
	type writestate_t is (NOINIT,IDLE,STARTBLOCK,WAITREADY,HANDLEBLOCK,FINISHBLOCK,UPDATEDPADDR);

  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;
	
	signal writeState, writeState_n : writestate_t := NOINIT;
	signal fval_old, fval_old_n : std_logic := '0';
	signal blockrdy_old, blockrdy_old_n : std_logic := '0';
	signal blockCount, blockCount_n : integer range 0 to 63 := 0;
	signal output, output_n : write_t;
	signal pixeladdr, pixeladdr_n : std_logic_vector(8 downto 0) := "000000000";
begin

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW, HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);
  
  control_proc : process(rst,dmai,dmao,fval,blockrdy,writeState,pixeladdr,rddata)
		variable wout : write_t;
  begin

		writeState_n <= writeState;
		fval_old_n <= fval;
		blockrdy_old_n <= blockrdy;
		blockCount_n <= blockCount;
		pixeladdr_n <= pixeladdr;
		wout := output;
		
		dmai.start <= '0';

		if rst = '1' and blockrdy_old /= blockrdy and blockrdy = '1' then
			blockCount_n <= blockCount + 1;
		end if;

		case writeState is
		when NOINIT =>
			if rst = '1' and fval_old /= fval and fval = '1' then
				writeState_n <= IDLE;
			end if;

		when IDLE =>
			if blockCount > 0 then
				writeState_n <= STARTBLOCK;
			end if;

		when STARTBLOCK =>
			writeState_n <= HANDLEBLOCK;
			wout.data := rddata;

		when HANDLEBLOCK =>
			dmai.start <= '1';
			if dmao.ready = '1' then
				--if output.data = COLORA then
				--	wout.data := COLORB;
				--else
				--	wout.data := COLORA;
				--end if;

				wout.data := rddata;
				wout.address := output.address + 4;
				if pixeladdr = conv_std_logic_vector(399,9) then
					pixeladdr_n <= "000000000";
				else
					pixeladdr_n <= pixeladdr + '1';
				end if;

				if wout.address(5 downto 2) = "0000" then
					dmai.start <= '0';
					blockCount_n <= blockCount - 1;
					writeState_n <= IDLE;
					wout.address := output.address + 4;
				end if;
				if wout.address = FIFOEND then
					wout.address := FIFOSTART;
				end if;
			end if;

		when others =>
		end case;
		
		output_n <= wout;
		rdaddress <= pixeladdr_n;
		
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		dmai.wdata <= wout.data;
		dmai.address <= wout.address;

		--if ((output_sig.rowcnt = output_sig.face.top or output_sig.rowcnt = output_sig.face.bottom)
		--		and (output_sig.colcnt >= output_sig.face.left and output_sig.colcnt <= output_sig.face.right))
		--	 or
		--	 ((output_sig.colcnt = output_sig.face.left or output_sig.colcnt = output_sig.face.right)
		--	  and (output_sig.rowcnt >= output_sig.face.top and output_sig.rowcnt <= output_sig.face.bottom)) then
		--	dmai.wdata <= x"0000ff00";
		--else
		--	dmai.wdata <= output_sig.data;
		--end if;
		--dmai.address <= output_sig.address;
		--dmai.start <= output_sig.start;
			
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(rst,clk)
  begin
    if rising_edge(clk) then
			if rst = '0' then
				writeState <= IDLE;
				fval_old <= '0';
				blockrdy_old <= '0';
				blockCount <= 0;
				output.address <= FIFOSTART;
				output.data <= COLORA;
				pixeladdr <= "000000000";
			else
				writeState <= writeState_n;
				fval_old <= fval_old_n;
				blockrdy_old <= blockrdy_old_n;
				blockCount <= blockCount_n;
				output <= output_n;
				pixeladdr <= pixeladdr_n;
			end if;
    end if;
  end process;
end;


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
	constant FIFOEND : std_logic_vector(31 downto 0) := x"E0176FFC";
	constant NOFACE : std_logic_vector(9 downto 0) := "1111111111";
	constant MAXCOL : integer := 400;
	constant MAXROW : integer := 240;

  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    

  type state_type is (running, not_running, reset);
  type job_type is (idle, busy);

  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;
	
	type facebox_t is record
		top					: std_logic_vector(9 downto 0);
		left				: std_logic_vector(9 downto 0);
		bottom			: std_logic_vector(9 downto 0);
		right				: std_logic_vector(9 downto 0);
	end record;

  type write_t is record
		face			: facebox_t;
		colcnt		: std_logic_vector(9 downto 0);
		rowcnt		: std_logic_vector(9 downto 0);
		address 	: std_logic_vector(31 downto 0);
		data			: std_logic_vector(31 downto 0);
		start			: std_logic;
  end record;

	type colors_t is array (0 to 3) of std_logic_vector(31 downto 0);

	signal numBlocks_sig,numBlocks_sig_n : INTEGER range 0 to 1000;
	signal pixelCount_sig,pixelCount_sig_n : INTEGER range 0 to 512;
  signal blockPartCount_sig,blockPartCount_sig_n : INTEGER range 0 to 16;

	signal facebox_sig,facebox_sig_n	: facebox_t;
  signal output_sig,output_sig_n	: write_t;

	signal writeState_sig,writeState_sig_n : writestate_type;
	signal dpaddr_sig,dpaddr_sig_n : std_logic_vector(8 downto 0);
	signal dpdata_sig,dpdata_sig_n : std_logic_vector(31 downto 0);

	signal blockready_sig,blockready_sig_n : std_logic;
	signal update_sig,update_sig_n : std_logic; --dbg
	signal ahbready_sig : std_logic; --dbg
  signal fval_old,fval_old_n : std_logic;
begin

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(rst,apbi,dmao,facebox_sig,output_sig,blockrdy,blockready_sig,update_sig,dpdata_sig,dpaddr_sig,writeState_sig,numBlocks_sig,pixelCount_sig,rddata)
    variable apbwrite	: std_logic;
    variable apbrdata : std_logic_vector(31 downto 0);
  	variable output	: write_t;
		variable facebox	: facebox_t;
		variable numBlocks : INTEGER range -10 to 100;
		variable pixelCount : INTEGER range 0 to 512;
		variable writeState : writestate_type;
		variable dpaddr : std_logic_vector(8 downto 0);
		variable dpdata : std_logic_vector(31 downto 0);
		variable ahbready : std_logic;
		variable update : std_logic; --dbg
  begin
		
		output := output_sig;
		facebox := facebox_sig;
		numBlocks := numBlocks_sig;
		pixelCount := pixelCount_sig;
		writeState := writeState_sig;
		dpaddr := dpaddr_sig;
		dpdata := dpdata_sig;
	
		apbrdata := (others => '0');
		update := update_sig;
		blockPartCount_sig_n <= blockPartCount_sig;
		fval_old_n <= fval_old;

	  ---------------------------------------------------------------------------
	  -- Control. Handles the APB accesses and stores the internal registers
	  ---------------------------------------------------------------------------
	  apbwrite :=  apbi.psel(pindex) and apbi.pwrite and apbi.penable;
	  case apbi.paddr(5 downto 2)  is
	  when "0000" =>
	    -- FB start address
	    --if apbwrite = '1' then
			--	if apbi.pwdata(0) = '1' then
			--		writectrl.write_en := '1';
			--	else
			--		writectrl.write_en := '0';
	    --	end if;
			--end if;
	    if apbwrite = '1' then
				if apbi.pwdata(0) = '1' then
					update := '1';
				else
					update := '0';
	    	end if;
			end if;
			apbrdata := x"DEADBABE";
	  when "0001" =>
	    -- Color register
	    --if apbwrite = '1' then
	    --	writectrl.data := apbi.pwdata;
	    --end if;
			--apbrdata := controlSig.data;
		when "0010" =>
			-- TopLeft address
			if apbwrite = '1' then
				facebox.top := apbi.pwdata(25 downto 16);
				facebox.left := apbi.pwdata(9 downto 0);
			end if;
			apbrdata := "000000" & facebox_sig.top & "000000" & facebox_sig.left;
		when "0011" =>
			-- BottomRight address
			if apbwrite = '1' then
				facebox.bottom := apbi.pwdata(25 downto 16);
				facebox.right := apbi.pwdata(9 downto 0);
			end if;
			apbrdata := "000000" & facebox_sig.bottom & "000000" & facebox_sig.right;
	  when others =>
	  end case;
		         
	
	  ---------------------------------------------------------------------------
	  -- Control reset
	  ---------------------------------------------------------------------------
	  if rst = '0' then
			numBlocks := 0;
			
			facebox.top := NOFACE;
			facebox.left := NOFACE;
			facebox.bottom := NOFACE;
			facebox.right := NOFACE;

			output.address := FIFOSTART;
			output.face := facebox;
			output.colcnt := (others => '0');
			output.rowcnt := (others => '0');

			writeState := NOINIT;
			dpaddr := (others => '0');
			dpdata := (others => '0');
			update := '0'; --dbg
			pixelCount := 0;
			blockPartCount_sig_n <= 0;
		end if;


		---------------------------------------------------------------------------
		-- Do write
		---------------------------------------------------------------------------
		 
		ahbready := dmao.ready;
		ahbready_sig <= dmao.ready;

		if rst = '1' and blockready_sig /= blockrdy and blockrdy = '1' then
		--if update_sig /= update and update = '1' then --dbg
			numBlocks := numBlocks + 1;
		end if;


	 	output.start := '0';

		case writeState is
		when NOINIT =>
			if rst = '1' and fval_old /= fval and fval = '1' then
				writeState := IDLE;
			end if;

		when IDLE =>
			if numBlocks > 0 then
				writeState := STARTBLOCK;
			end if;

		when STARTBLOCK =>
			output.start := '1';
			output.data := rddata;
			pixelCount := pixelCount + 1;

			writeState := HANDLEBLOCK;

		when HANDLEBLOCK =>
			output.start := '1';
			if ahbready = '1' then
				output.address := output.address + "100";
				output.colcnt := output.colcnt + '1';
				output.data := rddata;

				-- end of block
				if output.address(5 downto 2) = "0000" then
					output.start := '0';
					writeState := IDLE;
					numBlocks := numBlocks - 1;
					-- skip 400 pixels
					if output.colcnt = conv_std_logic_vector(MAXCOL,10) then
						output.address := output.address + x"640";
					end if;
				else
					pixelCount := pixelCount + 1;
				end if;
			end if;

		when others =>
		end case; -- writeState_sig

		if pixelCount = 512 then
		--if pixelCount = 400 then
			pixelCount := 0;
		end if;
		
		dpaddr := conv_std_logic_vector(pixelCount,9);

		-- increment column counter
		if output.colcnt = conv_std_logic_vector(MAXCOL,10) then
			output.colcnt := "0000000000";
			output.rowcnt := output.rowcnt + '1';
		end if;

		-- increment row counter
		if output.rowcnt = conv_std_logic_vector(MAXROW,10) then
			output.rowcnt := "0000000000";
			output.address := FIFOSTART;
			-- refresh face position
			output.face := facebox_sig;
		end if;

		--dbg ram-readout test
		--if output.data = x"00000000" then
		--	output.data := x"000000ff";
		--end if;

		--output.data := x"00FFA500";

		--output.data := "00000000000000000000000" & dpaddr; --dbg

		-- update signals
		update_sig_n <= update; --dbg
		blockready_sig_n <= blockrdy;
		dpaddr_sig_n <= dpaddr;
		facebox_sig_n <= facebox;
		output_sig_n <= output;
		pixelCount_sig_n <= pixelCount;
		numBlocks_sig_n <= numBlocks;
		writeState_sig_n <= writeState;
		
    apbo.prdata <= apbrdata;
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		if ((output_sig.rowcnt = output_sig.face.top or output_sig.rowcnt = output_sig.face.bottom)
				and (output_sig.colcnt >= output_sig.face.left and output_sig.colcnt <= output_sig.face.right))
			 or
			 ((output_sig.colcnt = output_sig.face.left or output_sig.colcnt = output_sig.face.right)
			  and (output_sig.rowcnt >= output_sig.face.top and output_sig.rowcnt <= output_sig.face.bottom)) then
			dmai.wdata <= x"0000ff00";
		else
			dmai.wdata <= output_sig.data;
		end if;
		dmai.address <= output_sig.address;
		dmai.start <= output_sig.start;
			
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
			fval_old <= fval_old_n;
			update_sig <= update_sig_n; --dbg
			blockready_sig <= blockready_sig_n;

			dpaddr_sig <= dpaddr_sig_n;
			dpdata_sig <= rddata;
			rdaddress <= dpaddr_sig_n;

			facebox_sig <= facebox_sig_n;
			output_sig <= output_sig_n;
			pixelCount_sig <= pixelCount_sig_n;
			numBlocks_sig <= numBlocks_sig_n;
			writeState_sig <= writeState_sig_n;
			blockPartCount_sig <= blockPartCount_sig_n;

    end if;
  end process;
 
  -- Boot message
  -- pragma translate_off
  bootmsg : report_version 
    generic map (
      "dispctrl" & tost(hindex) & ": Display data controller rev " &
      tost(REVISION) & ", AHB access size: " & tost(ahbaccsz) & " bits");
  -- pragma translate_on 
end;


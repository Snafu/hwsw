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
use hwswlib.all;
 
 
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
		rdaddress : out std_logic_vector(8 downto 0);
		rddata    : in std_logic_vector(31 downto 0);
		blockrdy  : in std_logic
    );

end ;

architecture rtl of dispctrl is
  
	constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0000000";
	constant FIFOEND : std_logic_vector(31 downto 0) := x"E0176FFC";
	constant NOFACE : std_logic_vector(9 downto 0) := "1111111111";

  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    

  type state_type is (running, not_running, reset);
  type job_type is (idle, busy);
	type writestate_type is (IDLE, STARTBLOCK, HANDLEBLOCK);

  signal ahbready							: std_logic;
  
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
		--top				: std_logic_vector(9 downto 0);
		--left			: std_logic_vector(9 downto 0);
		--bottom		: std_logic_vector(9 downto 0);
		--right			: std_logic_vector(9 downto 0);
		colcnt		: std_logic_vector(9 downto 0);
		rowcnt		: std_logic_vector(9 downto 0);
		address 	: std_logic_vector(31 downto 0);
		data			: std_logic_vector(31 downto 0);
		start			: std_logic;
  end record;

	signal numBlocks_sig,numBlocks_sig_n : INTEGER range -100 to 100;
	signal pixCount_sig,pixCount_sig_n : INTEGER range 0 to 511;
  
	signal facebox_sig,facebox_sig_n	: facebox_t;
  signal output_sig,output_sig_n	: write_t;

	signal writeState_sig,writeState_sig_n : writestate_type;
  
begin

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(rst,apbi,dmao,facebox_sig,output_sig)
    variable apbwrite	: std_logic;
    variable apbrdata : std_logic_vector(31 downto 0);
  	variable output	: write_t;
		variable facebox	: facebox_t;
		variable numBlocks : INTEGER range -100 to 100;
		variable pixCount : INTEGER range 0 to 511;
		variable writeState : writestate_type;
  begin
		
		output := output_sig;
		facebox := facebox_sig;
	
		apbrdata := (others => '0');
		
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
		end if;


		---------------------------------------------------------------------------
		-- Do write
		---------------------------------------------------------------------------
		 
		ahbready <= dmao.ready;

		if blockrdy = '1' then
			numBlocks := numBlocks + 1;
		end if;


	 	output.start := '0';

		case writeState_sig is
		when IDLE =>
			if numBlocks > 0 then
				writeState := STARTBLOCK;
				rdaddress <= conv_std_logic_vector(pixCount,9);
			end if;

		when STARTBLOCK =>
			output.start := '1';
			output.data := rddata;
			writeState := HANDLEBLOCK;

			-- increment pixelbuf counter
			if pixCount < 511 then
				pixCount := pixCount + 1;
			else
				pixCount := 0;
			end if;

			rdaddress <= conv_std_logic_vector(pixCount,9);

			-- increment column and row counter
			if output.colcnt = conv_std_logic_vector(799,10) then
				output.colcnt := "0000000000";
				if output.rowcnt = conv_std_logic_vector(479,10) then
					output.rowcnt := "0000000000";
					output.address := FIFOSTART;
				else
				 output.rowcnt := output.rowcnt + '1';
				end if;
			else
				output.colcnt := output.colcnt + '1';
			end if;
			

		when HANDLEBLOCK =>
			output.start := '1';
			if dmao.ready = '1' then
				output.address := output.address + "100";
				output.data := rddata;

				-- increment pixelbuf counter
				if pixCount < 511 then
					pixCount := pixCount + 1;
				else
					pixCount := 0;
				end if;

				rdaddress <= conv_std_logic_vector(pixCount,9);

				-- increment column and row counter
				if output.colcnt = conv_std_logic_vector(799,10) then
					output.colcnt := "0000000000";
					if output.rowcnt = conv_std_logic_vector(479,10) then
						output.rowcnt := "0000000000";
						output.address := FIFOSTART;
						-- refresh face position
						output.face := facebox_sig;
					else
					 output.rowcnt := output.rowcnt + '1';
					end if;
				else
					output.colcnt := output.colcnt + '1';
				end if;
			end if;

			-- end of block
			if output.address(3 downto 0) = (3 downto 0 => '0') then
				output.start := '0';
				writeState := IDLE;
				numBlocks := numBlocks - 1;
			end if;

		end case; -- writeState_sig


		-- update signals
		facebox_sig_n <= facebox;
		output_sig_n <= output;
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
			output_sig <= output_sig_n;
			facebox_sig <= facebox_sig_n;
			writeState_sig <= writeState_sig_n;
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


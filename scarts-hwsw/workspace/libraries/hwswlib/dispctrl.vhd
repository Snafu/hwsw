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
    ahbo      : out ahb_mst_out_type
    );

end ;

architecture rtl of dispctrl is
  
  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    

  type state_type is (running, not_running, reset);
  type job_type is (idle, busy);

  signal ahbready							: std_logic;
  
  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;
	
	type control_t is record
		top					: std_logic_vector(9 downto 0);
		left				: std_logic_vector(9 downto 0);
		bottom			: std_logic_vector(9 downto 0);
		right				: std_logic_vector(9 downto 0);
		data				: std_logic_vector(31 downto 0);
		startaddr		: std_logic_vector(31 downto 0);
		endaddr			: std_logic_vector(31 downto 0);
		write_en		: std_logic;
		write_done	: std_logic;
	end record;

  type write_t is record
		top				: std_logic_vector(9 downto 0);
		left			: std_logic_vector(9 downto 0);
		bottom		: std_logic_vector(9 downto 0);
		right			: std_logic_vector(9 downto 0);
		colcnt		: std_logic_vector(9 downto 0);
		rowcnt		: std_logic_vector(9 downto 0);
		address 	: std_logic_vector(31 downto 0);
		data			: std_logic_vector(31 downto 0);
		start			: std_logic;
		newburst	: std_logic;
		done			: std_logic;
  end record;
  
	signal controlSig,controlSig_n	: control_t;
  signal writeSig,writeSig_n	: write_t;
  
  signal vcc	: std_logic;
  
begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(rst,apbi,dmao)
    variable apbwrite	: std_logic;
    variable apbrdata : std_logic_vector(31 downto 0);
  	variable output	: write_t;
		variable writectrl	: control_t;
  begin
		
		output := writeSig;
		writectrl := controlSig;
	
		apbrdata := (others => '0');
		
	  ---------------------------------------------------------------------------
	  -- Control. Handles the APB accesses and stores the internal registers
	  ---------------------------------------------------------------------------
	  apbwrite :=  apbi.psel(pindex) and apbi.pwrite and apbi.penable;
	  case apbi.paddr(5 downto 2)  is
	  when "0000" =>
	    -- FB start address
	    if apbwrite = '1' then
				if apbi.pwdata(0) = '1' then
			  	writectrl.write_en := '1';
				else
					writectrl.write_en := '0';
	    	end if;
				apbrdata := (0 => controlSig.write_en, others => '0');
			end if;
			apbrdata := x"DEADBABE";
	  when "0001" =>
	    -- Color register
	    if apbwrite = '1' then
	    	writectrl.data := apbi.pwdata;
	    end if;
			--apbrdata := data;
			apbrdata := controlSig.data;
		when "0010" =>
			-- TopLeft address
			if apbwrite = '1' then
				writectrl.top := apbi.pwdata(25 downto 16);
				writectrl.left := apbi.pwdata(9 downto 0);
			end if;
			apbrdata := "000000" & controlSig.top & "000000" & controlSig.left;
		when "0011" =>
			-- BottomRight address
			if apbwrite = '1' then
				writectrl.bottom := apbi.pwdata(25 downto 16);
				writectrl.right := apbi.pwdata(9 downto 0);
			end if;
			apbrdata := "000000" & controlSig.bottom & "000000" & controlSig.right;
	  when others =>
	  end case;
		         
	
	  ---------------------------------------------------------------------------
	  -- Control reset
	  ---------------------------------------------------------------------------
	  if rst = '0' then
			writectrl.data := x"000FF000";
			writectrl.startaddr := x"E0000000";
			writectrl.endaddr := x"E0176FFC";
			writectrl.write_en := '0';
		end if;


		---------------------------------------------------------------------------
		-- Do write
		---------------------------------------------------------------------------
		 
		ahbready <= dmao.ready;
		
	 	output.start := '0';
		if rst = '0' or controlSig.write_en = '0' then
			output.newburst := '0';
			output.done := '0';
		elsif controlSig.write_en = '1' and writeSig.done = '0' then
			output.start := '1';
			if writeSig.start = '0' then
				output.newburst := '0';
				if writeSig.newburst = '0' then
					output.address := controlSig.startaddr;
					output.data := controlSig.data;
					output.colcnt := "0000000000";
					output.rowcnt := "0000000000";
					output.top := controlSig.top;
					output.left := controlSig.left;
					output.bottom := controlSig.bottom;
					output.right := controlSig.right;
				end if;
			end if;
			if writeSig.start = '1' and dmao.ready = '1' then
				output.newburst := '0';
				output.address := output.address + "100";
				if output.colcnt = conv_std_logic_vector(799,10) then
					output.colcnt := "0000000000";
					output.rowcnt := output.rowcnt + '1';
				else
					output.colcnt := output.colcnt + '1';
				end if;
				if output.address > controlSig.endaddr then
					output.start := '0';
					output.address := (others => '0');
					output.data := (others => '0');
					output.done := '1';
				elsif output.address(3 downto 0) = (3 downto 0 => '0') then
					output.newburst := '1';
					output.start := '0';
				end if;
			end if;
		end if;
			 
			
		writectrl.write_done := output.done;
		writeSig_n <= output;
		controlSig_n <= writectrl;
		
    apbo.prdata <= apbrdata;
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		if ((writeSig.rowcnt = writeSig.top or writeSig.rowcnt = writeSig.bottom) and (writeSig.colcnt >= writeSig.left and writeSig.colcnt <= writeSig.right)) or
			 ((writeSig.colcnt = writeSig.left or writeSig.colcnt = writeSig.right) and (writeSig.rowcnt >= writeSig.top and writeSig.rowcnt <= writeSig.bottom)) then
			dmai.wdata <= x"0000ff00";
		else
			dmai.wdata <= writeSig.data;
		end if;
		dmai.address <= writeSig.address;
		dmai.start <= writeSig.start;
		 
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
			writeSig <= writeSig_n;
			controlSig <= controlSig_n;
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


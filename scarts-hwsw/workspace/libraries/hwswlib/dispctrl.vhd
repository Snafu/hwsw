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
 
entity svgactrl is

  generic(
    memtech     : integer := DEFMEMTECH;
    pindex      : integer := 0;
    paddr       : integer := 0;
    pmask       : integer := 16#fff#;
    hindex      : integer := 0;
    hirq        : integer := 0;
    ahbaccsz    : integer := 32;
    );
  
  port (
    rst       : in std_logic;           -- Synchronous reset
    clk       : in std_logic;
    apbi      : in apb_slv_in_type;
    apbo      : out apb_slv_out_type;
    ahbi      : in  ahb_mst_in_type;
    ahbo      : out ahb_mst_out_type;
    clk_sel   : out std_logic_vector(1 downto 0);
    );

end ;

architecture rtl of dispctrl is
  
  constant REVISION : amba_version_type := 0; 
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    
  type register_type is array (1 to 5) of std_logic_vector(31 downto 0);

  type state_type is (running, not_running, reset);

  type control_type is record
    int_reg				: register_type;
    state				: state_type;
    enable				: std_logic;
    reset				: std_logic;
    address				: std_logic_vector(31 downto 0);
	color_a				: std_logic_vector(7 downto 0);
	color_b				: std_logic_vector(7 downto 0);
	data:				: std_logic_vector(31 downto 0);
  end record;
 
  
  signal r,rin			: control_type;
  signal dmai			: ahb_dma_in_type;
  signal dmao			: ahb_dma_out_type;
  signal color_a		: std_logic_vector(7 downto 0);
  signal color_b		: std_logic_vector(7 downto 0);
  signal ramaddress		: std_logic_vector(31 downto 0);
  
  signal vcc			: std_logic;

begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_GAISLER,
	GAISLER_DISPCTRL, 0, 3, 1)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(r,rst,apbi,dmao)
    variable v        : control_type;
    variable apbwrite : std_logic;
  begin
    v := c;
    ---------------------------------------------------------------------------
    -- Control. Handles the APB accesses and stores the internal registers
    ---------------------------------------------------------------------------
    apbwrite :=  apbi.psel(pindex) and apbi.pwrite and apbi.penable;
    case apbi.paddr(5 downto 2)  is
    when "0000" =>
      -- RAM register
      if apbwrite = '1' then
        v.address := apbi.pwdata;
      end if;
    when "0001" =>
      -- Color register
      if apbwrite = '1' then
        v.color_a := apbi.pwdata(7 downto 0);
	  	v.color_b := apbi.pwdata(15 downto 8);
      end if;
    when others =>
    end case;

	ramaddress <= v.address;
	color_a <= v.color_a;
	color_b <= v.color_b;

  end process;


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
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


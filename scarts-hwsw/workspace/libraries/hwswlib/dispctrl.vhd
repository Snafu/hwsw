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
  constant VENDOR_HWSW: amba_vendor_type := 0;
  constant HWSW_DISPCTRL: amba_device_type := 0;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
    

  type state_type is (running, not_running, reset);
  type job_type is (idle, busy);

  type control_type is record
    int_reg				: std_logic_vector(31 downto 0);
	 color_a				: std_logic_vector(31 downto 0);
	 color_b				: std_logic_vector(31 downto 0);
    state				: state_type;
    enable				: std_logic;
    reset				: std_logic;
	 updated				: std_logic;
    startaddr			: std_logic_vector(31 downto 0);
	 endaddr				: std_logic_vector(31 downto 0);
  end record;
  
  type work_type is record
    state				: job_type;
    color				: std_logic_vector(31 downto 0);
    addr					: std_logic_vector(31 downto 0);
  end record;
 
  
  signal r,rin			: control_type;
  signal w,win			: work_type;
  signal dmai			: ahb_dma_in_type;
  signal dmao			: ahb_dma_out_type;
  
  signal vcc			: std_logic;

begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 1)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(r,rst,apbi,dmao)
    variable v				: control_type;
	 variable k				: work_type;
    variable apbwrite	: std_logic;
  begin
    v := r;
	 
    ---------------------------------------------------------------------------
    -- Control. Handles the APB accesses and stores the internal registers
    ---------------------------------------------------------------------------
    apbwrite :=  apbi.psel(pindex) and apbi.pwrite and apbi.penable;
    case apbi.paddr(5 downto 2)  is
    when "0000" =>
      -- FB start address
      if apbwrite = '1' then
        v.startaddr := apbi.pwdata;
		  v.updated := '1';
      end if;
    when "0001" =>
      -- FB end address
      if apbwrite = '1' then
        v.endaddr := apbi.pwdata;
		  v.updated := '1';
      end if;
    when "0010" =>
      -- Color A register
      if apbwrite = '1' then
        v.color_a := apbi.pwdata;
		  v.updated := '1';
      end if;
	 when "0011" =>
	   -- Color B register
      if apbwrite = '1' then
        v.color_b := apbi.pwdata;
		  v.updated := '1';
      end if;
    when others =>
    end case;
	 
    ---------------------------------------------------------------------------
    -- Control state machine
    ---------------------------------------------------------------------------
    case r.state is
    when running => 
       if r.enable = '0' then
         v.state := not_running;
       end if;
    when not_running => 
       if r.enable = '1' then
         v.state := reset;
       end if;
    when reset =>
       v.state := running;
    end case;         

    ---------------------------------------------------------------------------
    -- Control reset
    ---------------------------------------------------------------------------
    if r.reset = '1' or rst = '0' then
      v.state     := not_running;
      v.enable    := '0';
		v.color_a	:= x"00deadf0";
		v.startaddr := x"00babe0a";
		v.endaddr	:= x"00babe0e";
		v.updated := '0';
      v.reset     := '0';
    end if; 

	 rin <= v;
  end process;
  
  -------------------------------------
  -- Write to RAM
  -------------------------------------
  ram_proc : process(r,w,dmai,dmao)
    variable k			: work_type;
	 variable v			: control_type;
  begin
    k := w;
	 v := r;
    if w.state = idle and r.updated = '1' then
		k.state := busy;
		k.addr := v.startaddr;
		k.color := v.color_a;
		v.updated := '0';
	 end if;
	 
	 dmai.address <= k.addr;
	 dmai.wdata <= k.color;
	 dmai.start <= '1';
	 
	 if dmao.ready = '1' and k.addr < r.endaddr then
	   k.addr := k.addr + 1;
		dmai.address <= k.addr + 1;
	 elsif dmao.ready = '1' and k.addr = r.endaddr then
	   k.state := idle;
		dmai.start <= '0';
	 end if;
	 
	 win <= k;
  
  end process;


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
      r <= rin;
		w <= win;
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


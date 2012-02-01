-----------------------------------------------------------------------------
-- Entity:      kamera
-- File:        kamera.vhd
-- Author:      Christopher Gabriel
-- Modified:    
-- Contact:     stuff@c-gabriel.at
-- Description: Cam readout
-----------------------------------------------------------------------------
-- GRLIB2 CORE
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
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;
library techmap;
use techmap.gencomp.all;
library gaisler;
use gaisler.misc.all;

library work;
use work.hwswlib.all;
 
 
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
    rst       : in std_logic;           -- Synchronous reset
    clk       : in std_logic;
--    apbi      : in apb_slv_in_type;
--    apbo      : out apb_slv_out_type;
--    ahbi      : in  ahb_mst_in_type;
--    ahbo      : out ahb_mst_out_type;
		pixclk		: in std_logic;
		fval			: in std_logic;
		lval			: in std_logic;
		pixdata		: in std_logic_vector(11 downto 0);
		sramo			: out sram_t
    );

end ;

architecture rtl of kamera is
  
--  constant REVISION : amba_version_type := 0; 
--  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
--  constant HWSW_CAM: amba_device_type := 16#14#;
--  constant PCONFIG : apb_config_type := (
--     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_CAM, 0, REVISION, 0),
--     1 => apb_iobar(paddr, pmask));
--  
--  signal dmai	: ahb_dma_in_type;
--  signal dmao	: ahb_dma_out_type;

  signal vcc	: std_logic;
	
	type sram_t is record
		addr		: std_logic_vector(19 downto 0);
		data		: std_logic_vector(15 downto 0);
		we			: std_logic;
		oe			: std_logic;
		ce			: std_logic;
		ub			: std_logic;
		lb			: std_logic;
	end record;
	
	type color_t is (R,G,B);
	type pixel_t is array(color_t'left to color_t'right) of std_logic_vector(7 downto 0);
	type pixline_t is array(1 to 800) of pixel_t;
	type line_t is (FIRST, SECOND);
	
	
	signal pixclk_old : std_logic;
	
	signal fval_old		: std_logic;
	signal fval_old_next	: std_logic;
	
	signal linecnt			: std_logic_vector(0 to 9); 
	signal linecnt_next	: std_logic_vector(0 to 9);
  
	signal rowcnt			: std_logic_vector(0 to 9);
	signal rowcnt_next	: std_logic_vector(0 to 9);
	
	signal whichline		: line_t;
	signal whichline_next: line_t;
  
begin

  vcc <= '1';

--  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
--	HWSW_CAM, 0, 3, 0)
--  port map (rst, clk, dmai, dmao, ahbi, ahbo);     
--
--  apbo.pirq    <= (others => '0');
--  apbo.pindex  <= pindex;
--  apbo.pconfig <= PCONFIG;
  
  --readout : process(rst,apbi,dmao,dmai,s,c)
  readout : process(rst,fval,lval,pixdata,pixclk)
	begin
		
		fval_old_next <= fval;
		lval_old_next <= lval;
		
		-- rising edge of FVAL -> NEW FRAME starts
		if(fval_old /= fval and fval = '1')
		then
			whichline_next <= FIRST;
			rowcnt_next  <= "0000000000";
			linecnt_next <= "0000000000";			
		end if;
		
		if(lval_old /= lval and lval = '1')
		then
		
		end if;
		
		-- rising edge of pxclk -> valid BAYER data from cam
		if fval = '1' and lval = '1' and pixclk_old /= pixclk and pixclk = '1'
		then
		
		end if;
			
		
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
  	if(rst = '0')
	then
		fval_old <= '0';
		linecnt <= "0000000000";
		rowcnt <=  "0000000000";
		whichline <= FIRST;
	else
		if rising_edge(clk)
		then
			linecnt <= linecnt_next;
			rowcnt <= rowcnt_next;
			whichline <= whichline_next;
			
			pixclk_old <= pixclk;
			fval_old <= fval_old_next;
		end if;
	end if;
	end process;
  


  -- Boot message
  -- pragma translate_off
  bootmsg : report_version 
    generic map (
      "kamera" & tost(hindex) & ": Cam readout");
  -- pragma translate_on
  
end;


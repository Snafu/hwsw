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
	
	type convert_t is record
		addr		: integer range 0 to 800*480*2-1;
		cdata		: std_logic_vector(15 downto 0);
		ccnt		: integer range 1 to 800;
		rcnt		: integer range 1 to 480;
		lcnt		: line_t;
		col			: color_t;
	end record;
	
	signal s,s_in		: sram_t;
	signal c,c_in		: convert_t;
	signal pixclk_old : std_logic;
  
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
  readout : process(rst,fval,lval,pixdata,pixclk,s,c)
		variable v		: sram_t;
		variable w		: convert_t;
	begin
		v := s;
		w := c;
		
		v.ce := '1';
		
		if fval = '1' and lval = '1' and pixclk_old /= pixclk and pixclk = '1' then
			case c.lcnt is
			-- First pixel half-line
			when FIRST =>
				if c.ccnt = 0 then
					w.addr := 0;
				end if;
				
				case c.col is
				when G =>
					w.cdata(7 downto 0) := pixdata(11 downto 4);
					w.col := R;
					
				when R =>
					w.cdata(15 downto 8) := pixdata(11 downto 4);
					if c.ccnt = 800 then
						w.col := B;
						w.ccnt := 1;
						w.rcnt := w.rcnt + 1;
						w.lcnt := SECOND;
					else
						w.col := G;
						w.ccnt := w.ccnt + 1;
					end if;
					
				when others =>
				end case;
			
			-- Second pixel half-line
			when SECOND =>
				if c.ccnt = 0 then
					w.addr := 1;
				end if;
				
				case c.col is
				when B =>
					w.cdata(7 downto 0) := pixdata(11 downto 4);
					w.col := G;
					
				when G =>
					w.cdata(15 downto 8) := pixdata(11 downto 4);
					if c.ccnt = 800 then
						w.col := R;
						w.ccnt := 1;
						w.rcnt := w.rcnt + 1;
						w.lcnt := SECOND;
					else
						w.col := B;
						w.ccnt := w.ccnt + 1;
					end if;
					
				when others =>
				end case;
			end case;
					
			v.we := '0';
			v.ce := '0';
			v.oe := '0';
			v.ub := '0';
			v.lb := '0';
			v.addr := conv_std_logic_vector(w.addr,20);
			v.data := w.cdata;
			w.addr := w.addr + 2;
		end if;
		
		if rst = '1' or fval = '0' then
			v.ce := '1';
			w.rcnt := 1;
			w.ccnt := 1;
			w.lcnt := FIRST;
			w.col := G;
			w.addr := 0;
		end if;
		
		s_in <= v;
		c_in <= w;
		
		
		sramo.addr <= v.addr;
		sramo.data <= v.data;
		sramo.we <= v.we;
		sramo.oe <= v.oe;
		sramo.ub <= v.ub;
		sramo.lb <= v.lb;
		
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
			s <= s_in;
			c <= c_in;
			pixclk_old <= pixclk;
    end if;
  end process;
  


  -- Boot message
  -- pragma translate_off
  bootmsg : report_version 
    generic map (
      "kamera" & tost(hindex) & ": Cam readout");
  -- pragma translate_on
  
end;


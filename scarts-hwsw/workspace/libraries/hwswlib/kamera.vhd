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

library hwswlib;
use hwswlib.all;
 
 
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
    apbi      : in apb_slv_in_type;
    apbo      : out apb_slv_out_type;
    ahbi      : in  ahb_mst_in_type;
    ahbo      : out ahb_mst_out_type;
		fval			: in std_logic;
		lval			: in std_logic;
		pixdata		: in std_logic_vector(11 downto 0)
    );

end ;

architecture rtl of kamera is
  
  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_CAM: amba_device_type := 16#14#;
  constant PCONFIG : apb_config_type := (
     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_CAM, 0, REVISION, 0),
     1 => apb_iobar(paddr, pmask));
  
  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;

  signal vcc	: std_logic;
	
	type color_t is (R,G,B);
	type pixel_t is array(color_t'left to color_t'right) of std_logic_vector(7 downto 0);
  type pixline_t is array(1 to 800) of pixel_t;
	type line_t is (FIRST, SECOND);
	
	signal pixel						: pixline_t;
	signal coldata_in 			: std_logic_vector(11 downto 0);
	signal cnt,cnt_in 			: integer range 1 to 800;
	signal col,col_in 			: color_t;
	signal pline,pline_in 	: line_t;
  
begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_CAM, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  readout : process(rst,apbi,dmao,dmai,fval,lval,pixdata,col,col_in,cnt,coldata_in,pline)
		--variable _coldata : std_logic_vector(7 downto 0);
  begin
		if fval = '1' and lval = '1' then
			--_coldata := pixdata(11 downto 4);
			coldata_in <= pixdata(11 downto 4);
			case pline is
			-- First pixel half-line
			when FIRST =>
				case col is
				when G =>
					col_in <= R;
					
				when R =>
					if cnt = 800 then
						col_in <= B;
						cnt_in <= 0;
						pline_in <= SECOND;
					else
						col_in <= G;
						cnt_in <= cnt + 1;
					end if;
				when others =>
				end case;
			
			-- Second pixel half-line
			when SECOND =>
				case col is
				when B =>
					col_in <= G;
					
				when G =>
					if cnt = 800 then
						col_in <= G;
						cnt_in <= 0;
						pline_in <= FIRST;
					else
						col_in <= B;
						cnt_in <= cnt + 1;
					end if;
					
				when others =>
				end case;
			end case;
			
		end if;
		
		if rst = '1' then
			col_in <= G;
			cnt_in <= 1;
			pline_in <= FIRST;
		end if;
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
			pline <= pline_in;
			col <= col_in;
			cnt <= cnt_in;
			if pline = SECOND and col = G then
				pixel(cnt)(col) <= conv_std_logic_vector(conv_integer(coldata_in) + conv_integer(pixel(cnt)(col)),8);
			else
				pixel(cnt)(col) <= coldata_in;
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


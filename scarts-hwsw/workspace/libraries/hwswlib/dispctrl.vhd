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
--  constant PCONFIG : apb_config_type := (
--     0 => ahb_device_reg ( VENDOR_HWSW, HWSW_DISPCTRL, 0, REVISION, 0),
--     1 => apb_iobar(paddr, pmask));
    

  type state_type is (running, not_running, reset);
  type job_type is (idle, busy);

  signal int_reg,int_reg_in			: std_logic_vector(31 downto 0);
  signal data,data_in					: std_logic_vector(31 downto 0);
  signal startaddr,startaddr_in		: std_logic_vector(31 downto 0);
  signal endaddr,endaddr_in			: std_logic_vector(31 downto 0);
  signal write_en,write_en_in			: std_logic;
  signal write_done,write_done_in	: std_logic;
  signal tmpaddr,tmpaddr_next : std_logic_vector(31 downto 0);
  signal ready : std_logic;
  signal counter,counter_next : integer;
 
  
  signal dmai			: ahb_dma_in_type;
  signal dmao			: ahb_dma_out_type;
  
  signal vcc			: std_logic;
  
  type wstates is (idle, initwrite, waitready, interburst, contwrite, done);
  
  signal wstate,wstate_next : wstates;

begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 1)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

--  apbo.pirq    <= (others => '0');
--  apbo.pindex  <= pindex;
--  apbo.pconfig <= PCONFIG;
  
  control_proc : process(rst,apbi,dmao,dmai,write_done,write_en)
    variable apbwrite	: std_logic;
  begin
	 
--    ---------------------------------------------------------------------------
--    -- Control. Handles the APB accesses and stores the internal registers
--    ---------------------------------------------------------------------------
--    apbwrite :=  apbi.psel(pindex) and apbi.pwrite and apbi.penable;
--    case apbi.paddr(5 downto 2)  is
--    when "0000" =>
--      -- FB start address
--      if apbwrite = '1' then
--        v.startaddr := apbi.pwdata;
--		  v.updated := '1';
--      end if;
--    when "0001" =>
--      -- FB end address
--      if apbwrite = '1' then
--        v.endaddr := apbi.pwdata;
--		  v.updated := '1';
--      end if;
--    when "0010" =>
--      -- Color A register
--      if apbwrite = '1' then
--        v.color_a := apbi.pwdata;
--		  v.updated := '1';
--      end if;
--	 when "0011" =>
--	   -- Color B register
--      if apbwrite = '1' then
--        v.color_b := apbi.pwdata;
--		  v.updated := '1';
--      end if;
--    when others =>
--    end case;
	         

    ---------------------------------------------------------------------------
    -- Control reset
    ---------------------------------------------------------------------------
    if rst = '0' then
		--data_in	<= x"00deadf0";
		--startaddr_in <= x"00babe0a";
		--endaddr_in	<= x"00babe0e";
		data_in <= x"0000FF00";
		startaddr_in <= x"E0000000";
		endaddr_in	<= x"E0177000";
		write_en_in <= '0';
	 else
		write_en_in <= '1';
	 end if;
	 
	 

  end process;
  
  -------------------------------------
  -- Write to RAM
  -------------------------------------
  write_proc : process(rst,wstate,wstate_next,dmai,dmao,write_en,tmpaddr,tmpaddr_next,startaddr,endaddr,data)
	--variable counter: integer := 0;
  begin
		ready <= dmao.ready;
	 if rst = '0' then
		wstate_next <= idle;
	 else
	 
		case wstate is
		
		when idle =>
			if write_en = '1' then
				--tmpaddr := startaddr;
				tmpaddr_next <= startaddr;
				
				wstate_next <= initwrite;
				counter_next <= 0;
			end if;
		
		when initwrite =>
			dmai.burst <= '1';
			dmai.irq <= '0';
			dmai.size <= "010";
			dmai.write <= '1';
			dmai.busy <= '0';
			dmai.wdata <= data;
			dmai.address <= tmpaddr;
			dmai.start <= '1';
			tmpaddr_next <= tmpaddr + "100";
			counter_next <= 1;
			
			wstate_next <= contwrite;
				
		when contwrite =>
			if dmao.ready = '1' then
				if counter = 8 and tmpaddr <= endaddr then
					dmai.start <= '0';
					dmai.address <= tmpaddr;
					counter_next <= 0;
					
					wstate_next <= initwrite;
				elsif tmpaddr > endaddr then
				--if tmpaddr > endaddr then
					dmai.start <= '0';
					dmai.wdata <= (others => '0');
					dmai.address <= (others => '0');
					write_done_in <= '1';
					
					wstate_next <= done;
				else
					dmai.wdata <= data;
					--dmai.address <= tmpaddr;
					tmpaddr_next <= tmpaddr + "100";
					counter_next <= counter + 1;
				end if;
			end if;
		
		when interburst =>
			wstate_next <= initwrite;
		
		when done =>
			if write_en = '0' then
				wstate_next <= idle;
			end if;
		
		when others =>
		end case;
		 
	 end if;
	 
  end process;


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
		data <= data_in;
		startaddr <= startaddr_in;
		endaddr <= endaddr_in;
		write_en <= write_en_in;
		write_done <= write_done_in;
		wstate <= wstate_next;
		tmpaddr <= tmpaddr_next;
		counter <= counter_next;
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


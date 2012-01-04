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

	signal top,top_in		: std_logic_vector(9 downto 0);
	signal left,left_in		: std_logic_vector(9 downto 0);
	signal bottom,bottom_in		: std_logic_vector(9 downto 0);
	signal right,right_in		: std_logic_vector(9 downto 0);
  signal data,data_in					: std_logic_vector(31 downto 0);
  signal startaddr,startaddr_in			: std_logic_vector(31 downto 0);
  signal endaddr,endaddr_in				: std_logic_vector(31 downto 0);
  signal write_en,write_en_in			: std_logic;
  signal write_done,write_done_in		: std_logic;
  signal ahbready							: std_logic;
  
  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;

  type write_t is record
		top			: std_logic_vector(9 downto 0);
		left			: std_logic_vector(9 downto 0);
		bottom			: std_logic_vector(9 downto 0);
		right			: std_logic_vector(9 downto 0);
		colcnt	: integer range 0 to 799;
		rowcnt	: integer range 0 to 49;
		address 	: std_logic_vector(31 downto 0);
		data		: std_logic_vector(31 downto 0);
		start		: std_logic;
		newburst	: std_logic;
		done		: std_logic;
  end record;
  
  signal r,rin	: write_t;
  
  signal vcc	: std_logic;
  
begin

  vcc <= '1';

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW,
	HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);     

  apbo.pirq    <= (others => '0');
  apbo.pindex  <= pindex;
  apbo.pconfig <= PCONFIG;
  
  control_proc : process(rst,apbi,dmao,dmai,r,write_en,data)
    variable apbwrite	: std_logic;
    variable apbrdata : std_logic_vector(31 downto 0);
  	variable v	: write_t;
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
				if apbi.pwdata(0) = '1' then
			  	write_en_in <= '1';
				else
					write_en_in <= '0';
	    	end if;
				--apbrdata := (0 => write_en, others => '0');
			end if;
			apbrdata := x"DEADBABE";
--	  when "0001" =>
--	    -- FB end address
--	    if apbwrite = '1' then
--	      v.endaddr := apbi.pwdata;
--				v.updated := '1';
--	  	end if;
	  when "0001" =>
	    -- Color register
	    if apbwrite = '1' then
	    	data_in <= apbi.pwdata;
	    end if;
			apbrdata := data;
		when "0010" =>
			-- TopLeft address
			if apbwrite = '1' then
				top_in <= apbi.pwdata(25 downto 16);
				left_in <= apbi.pwdata(9 downto 0);
			end if;
			
			-- 
			--		FIXME
			--
			--apbrdata := (25 downto 16 => top, 9 downto 0 => left, others => '0');
		when "0011" =>
			-- BottomRight address
			if apbwrite = '1' then
				bottom_in <= apbi.pwdata(25 downto 16);
				right_in <= apbi.pwdata(9 downto 0);
			end if;
			
			-- 
			--		FIXME
			--
			--apbrdata := (25 downto 16 => bottom, 9 downto 0 => right, others => '0');
	  when others =>
	  end case;
		         
	
	  ---------------------------------------------------------------------------
	  -- Control reset
	  ---------------------------------------------------------------------------
	  if rst = '0' then
			data_in <= x"000FF000";
			startaddr_in <= x"E0000000";
			endaddr_in	<= x"E0176FFC";
			write_en_in <= '0';
		end if;


		---------------------------------------------------------------------------
		-- Do write
		---------------------------------------------------------------------------
		 
		ahbready <= dmao.ready;
		
	 	v.start := '0';
		if rst = '0' or write_en = '0' then
			v.newburst := '0';
			v.done := '0';
		elsif write_en = '1' and r.done = '0' then
			v.start := '1';
			if r.start = '0' then
				v.newburst := '0';
				if r.newburst = '0' then
					v.address := startaddr;
					v.data := data;
					v.colcnt := 0;
					v.rowcnt := 0;
					v.top := top;
					v.left := left;
					v.bottom := bottom;
					v.right := right;
				end if;
			end if;
			if r.start = '1' and dmao.ready = '1' then
				v.newburst := '0';
				v.address := v.address + "100";
				if v.colcnt = 799 then
					v.colcnt := 0;
					v.rowcnt := v.rowcnt + 1;
				else
					v.colcnt := v.colcnt + 1;
				end if;
				if v.address > endaddr then
					v.start := '0';
					v.address := (others => '0');
					v.data := (others => '0');
					v.done := '1';
				elsif v.address(3 downto 0) = (3 downto 0 => '0') then
					v.newburst := '1';
					v.start := '0';
				end if;
			end if;
		end if;
			 
			
		rin <= v;
    apbo.prdata <= apbrdata;
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		
		
		--
		--		FIXME
		--
		--if ((r.colcnt = r.top or r.colcnt = r.bottom) and (r.rowcnt >= r.left and r.rowcnt <= r.right)) or
		--	 ((r.colcnt >= r.top and r.colcnt <= r.bottom) and (r.rowcnt = r.left or r.rowcnt = r.right)) then
		--	dmai.wdata <= x"0000ff00";
		--else
		--	dmai.wdata <= r.data;
		--end if;
		
		
		dmai.address <= r.address;
		dmai.start <= r.start;
		write_done_in <= r.done;
		 
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------
  reg_proc : process(clk)
  begin
    if rising_edge(clk) then
			r <= rin;
			data <= data_in;
			startaddr <= startaddr_in;
			endaddr <= endaddr_in;
			write_en <= write_en_in;
			write_done <= write_done_in;
			top <= top_in;
			left <= left_in;
			right <= right_in;
			bottom <= bottom_in;
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


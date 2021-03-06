-----------------------------------------------------------------------
-- This file is part of SCARTS.
-- 
-- SCARTS is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
-- 
-- SCARTS is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with SCARTS.  If not, see <http://www.gnu.org/licenses/>.
-----------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;

use work.top_pkg.all;
use work.scarts_pkg.all;
use work.scarts_amba_pkg.all;
use work.pkg_dis7seg.all;
use work.pkg_counter.all;
use work.ext_miniUART_pkg.all;
use work.sync_pkg.all;

library grlib;
use grlib.amba.all;

library techmap;
use techmap.gencomp.all;

library gaisler;
use gaisler.misc.all;
use gaisler.memctrl.all;

library hwswlib;
use work.hwswlib.all;
use work.i2clib.all;
use work.kameralib.all;

entity top is
  port(
		db_clk      : in  std_ulogic;
		rst         : in  std_ulogic;
		-- Debug Interface
		D_RxD       : in  std_logic; 
		D_TxD       : out std_logic;
		-- 7Segment Anzeige
		digits      : out digit_vector_t(7 downto 0);
		-- SDRAM Controller Interface (AMBA)
		sdcke       : out std_logic;
		sdcsn       : out std_logic;
		sdwen       : out std_logic;
		sdrasn      : out std_logic;
		sdcasn      : out std_logic;
		sddqm       : out std_logic_vector(3 downto 0);
		sdclk       : out std_logic;
		sa          : out std_logic_vector(14 downto 0);
		sd          : inout std_logic_vector(31 downto 0);
		-- LCD (AMBA)
		ltm_hd      : out std_logic;
		ltm_vd      : out std_logic;
		ltm_r       : out std_logic_vector(7 downto 0);
		ltm_g       : out std_logic_vector(7 downto 0);
		ltm_b       : out std_logic_vector(7 downto 0);
		ltm_nclk    : out std_logic;
		ltm_den     : out std_logic;
		ltm_grest   : out std_logic;
		-- AUX UART
		aux_uart_rx : in  std_logic;
		aux_uart_tx : out std_logic;
		-- I2C
		i2c_scl		:	out std_logic;
		i2c_sda		:	out std_logic;
--		i2c_scl_dbg:	out std_logic;
--		i2c_sda_dbg:	out std_logic;
--		i2c_trigger:	out std_logic;
		-- CAM
		cam_pixclk		: in std_logic;
		cam_fval			: in std_logic;
		cam_lval			: in std_logic;
		cam_pixdata		: in std_logic_vector(11 downto 0);
		cam_resetN		: out std_logic;
		cam_pll_input	: out std_logic;
		cam_trigger		: out std_logic;		-- hardware trigger for camera

		-- BUTTONS
		key3			: in std_logic;
		key2			: in std_logic;
		key1			: in std_logic;
			
		sw17			: in std_logic;
		sw16			: in std_logic;
		sw15			: in std_logic;
		sw14			: in std_logic;
		sw13			: in std_logic;
		sw12			: in std_logic;
		sw11			: in std_logic;
		sw10			: in std_logic;
		sw9				: in std_logic;
		sw8				: in std_logic;
		sw7				: in std_logic;
		sw6				: in std_logic;
		sw5				: in std_logic;
		sw4				: in std_logic;
		sw3				: in std_logic;
		sw2				: in std_logic;
		sw1				: in std_logic;
		sw0				: in std_logic;

		-- TESTSIGNALE
		blockrdy_dbg			: out std_logic;
--		whichLine_top_dbg	: out std_logic;
		sysclk						:	out std_logic;
		clk_pixel_dbg			:	out std_logic;
--		cam_resetN_dbg		: out std_logic;

--		wren_sig_dbg			: out std_logic;
		
		ahbready_dbg			: out std_logic;
		
		cam_fval_dbg			: out std_logic;
		cam_lval_dbg			: out std_logic;
--		cam_pixdata_dbg		: out std_logic_vector(11 downto 0);
		
		-- DEBUG
--		camstate					: out state_t;
		rdreq_dbg					: out std_logic;
		wrreq_dbg					: out std_logic;
		clearfifo_dbg			: out std_logic
  );
end top;

architecture behaviour of top is
  
	-- clock signals
	signal cam_pll_input_sig	: std_logic;
	signal clk_pixel					: std_logic;


	-- multiplier signals
  signal mult_config_sel		: std_ulogic;
  signal mult_exto 					: module_out_type;
  
	-- kamera signals
	signal pxReady_sig				: std_logic;
	signal pxReady_sync				: std_logic;
	signal whichLine_sig			: std_logic;
	signal cam_counter				: integer range 0 to 4;
	signal cam_counter_next		: integer range 0 to 4;
	signal cam_syncrst				: std_logic;
	signal cam_pixdata_sync		: std_logic_vector(11 downto 0);
	signal cam_fval_sync			: std_logic;
	signal cam_lval_sync			: std_logic;

	-- kamera control signals
  signal cam_config_sel			: std_ulogic;
  signal cam_exto 					: module_out_type;
	signal yR_fac							: std_logic_vector(8 downto 0);
	signal yG_fac							: std_logic_vector(8 downto 0);
	signal yB_fac							: std_logic_vector(8 downto 0);
	signal yMin								: integer range 0 to 255;
	signal yMax								: integer range 0 to 255;
	
	signal cbR_fac						: std_logic_vector(8 downto 0);
	signal cbG_fac						: std_logic_vector(8 downto 0);
	signal cbB_fac						: std_logic_vector(8 downto 0);
	signal cbMin							: integer range 0 to 255;
	signal cbMax							: integer range 0 to 255;
	
	signal crR_fac						: std_logic_vector(8 downto 0);
	signal crG_fac						: std_logic_vector(8 downto 0);
	signal crB_fac						: std_logic_vector(8 downto 0);
	signal crMin							: integer range 0 to 255;
	signal crMax							: integer range 0 to 255;

	signal output_mode				: std_logic;

	-- signals for BUTTONS Extension Module
  signal buttons_config_sel	: std_ulogic;
  signal buttons_exto 			: module_out_type;

  -- signals for DISPLAY Controller
  signal disp_config_sel		: std_ulogic;
  signal disp_exto 					: module_out_type;
  signal disp_ahbmo					: ahb_mst_out_type;
	signal disp_fval					:	std_logic;
  
  -- signals for i2cmst
	--signal i2ci_pin			:	i2c_in_type;
	signal i2co_pin				:	i2c_out_type;
	signal i2c_config_sel	:	std_logic	:= '0';
  --signal i2c_exto				: module_out_type;
  
  -- dpram
	signal data_sig						:  STD_LOGIC_VECTOR (31 DOWNTO 0);
	signal rdaddress_sig			:  STD_LOGIC_VECTOR (8 DOWNTO 0);
	signal rdclock_sig				:  STD_LOGIC ;
	signal wraddress_sig			:  STD_LOGIC_VECTOR (8 DOWNTO 0);
	signal wrclock_sig				:  STD_LOGIC  := '1';
	signal wren_sig						:  STD_LOGIC  := '0';
	signal q_sig							:  STD_LOGIC_VECTOR (31 DOWNTO 0);
  
  
  signal scarts_i						: scarts_in_type;
  signal scarts_o						: scarts_out_type;

  signal debugi_if					: debug_if_in_type;
  signal debugo_if					: debug_if_out_type;

  signal exti								: module_in_type;
  
  signal syncrst						: std_ulogic;
  signal sysrst							: std_ulogic;

  signal clk								: std_logic;

  -- 7-segment display
  signal dis7segsel  : std_ulogic;
  signal dis7segexto : module_out_type;

  -- signals for counter extension module
  signal counter_segsel : std_logic;
  signal counter_exto : module_out_type;
  
  -- signals for AHB slaves and APB slaves
  signal ahbmi            : ahb_master_in_type;
  signal scarts_ahbmo      : ahb_master_out_type;
  signal grlib_ahbmi      : ahb_mst_in_type;
  signal grlib_ahbmo      : ahb_mst_out_vector;
  signal ahbsi            : ahb_slv_in_type;
  signal ahbso            : ahb_slv_out_vector; 
  signal apbi             : apb_slv_in_type;
  signal apbo             : apb_slv_out_vector;
  signal apb_bridge_ahbso : ahb_slv_out_type;
  signal sdram_ahbso      : ahb_slv_out_type;

  -- signals for SDRAM Controller
  signal sdi            : sdctrl_in_type;
  signal sdo            : sdctrl_out_type;
  
  -- signals for VGA Controller
  signal vgao           : apbvga_out_type;
  signal vga_clk_int    : std_logic;
  signal vga_clk_sel    : std_logic_vector(1 downto 0);
  signal svga_ahbmo     : ahb_mst_out_type;

  -- signals for AUX UART
  signal aux_uart_sel      : std_ulogic;
  signal aux_uart_exto     : module_out_type;
  
  -- extension module: signal when camera is configured by i2c
  signal hw_initialized		: std_logic;
  
  component cam_pll IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0				: OUT STD_LOGIC
	);
	END component;
  
  
	component altera_pll IS
	PORT
	(
		areset		: IN STD_LOGIC  := '0';
		inclk0		: IN STD_LOGIC  := '0';
		c0				: OUT STD_LOGIC;
		c1				: OUT STD_LOGIC;
		locked		: OUT STD_LOGIC
	);
	END component;

begin

	sysclk <= clk;

	-----------------------------------------------------------------------------
	-- PLLs
	-----------------------------------------------------------------------------

  altera_pll_inst : altera_pll
		PORT MAP
		(
    	areset		=> '0',
    	inclk0		=> db_clk,
    	c0				=> clk,
    	c1				=> vga_clk_int,
    	locked		=> open
    );
	 
	cam_pll_inst : cam_pll
		PORT MAP
		(
			areset		=> '0',
			inclk0		=> cam_pixclk,
			c0				=> clk_pixel
		);


	-----------------------------------------------------------------------------
	-- Synchronizers
	-----------------------------------------------------------------------------

	sync_disp_fval : sync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0'
		)
		port map
		(
			sys_clk => clk_pixel,
			sys_res_n => rst,
			data_in => cam_fval,
			data_out => disp_fval
		);

	sync_cam_rst : sync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0'
		)
		port map
		(
			sys_clk => clk_pixel,
			sys_res_n => rst,
			data_in => rst,
			data_out => cam_syncrst
		);

	sync_fval : nsync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0'
		)
		port map
		(
			sys_clk => clk_pixel,
			sys_res_n => rst,
			data_in => cam_fval,
			data_out => cam_fval_sync
		);
	
	sync_lval : nsync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0'
		)
		port map
		(
			sys_clk => clk_pixel,
			sys_res_n => rst,
			data_in => cam_lval,
			data_out => cam_lval_sync
		);
	
	sync_pixdata : nvectorsync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0',
			VECTOR_LENGTH => 12
		)
		port map
		(
			sys_clk => clk_pixel,
			sys_res_n => rst,
			data_in => cam_pixdata,
			data_out => cam_pixdata_sync
		);

	sync_pxReady : nsync
		generic map
		(
			SYNC_STAGES => 2,
			RESET_VALUE => '0'
		)
		port map
		(
			sys_clk => clk,
			sys_res_n => rst,
			data_in => pxReady_sig,
			data_out => pxReady_sync
		);


	-----------------------------------------------------------------------------
	-- SCARTS
	-----------------------------------------------------------------------------
		
  scarts_unit: scarts
    generic map (
    CONF => (
      tech => work.scarts_pkg.ALTERA,
      word_size => 32,
      boot_rom_size => 12,
      instr_ram_size => 16,
      data_ram_size => 17,
      use_iram => true,
      use_amba => true,
      amba_shm_size => 8,
      amba_word_size => 32,
      gdb_mode => 0,
      bootrom_base_address => 29
      ))
    port map(
      clk    => clk,
      sysrst => sysrst,
      extrst => syncrst,
      scarts_i => scarts_i,
      scarts_o => scarts_o,
      ahbmi  => ahbmi,
      ahbmo  => scarts_ahbmo,
      debugi_if => debugi_if,
      debugo_if => debugo_if
      );


	-----------------------------------------------------------------------------
	-- AMBA AHB arbiter/multiplexer
	-----------------------------------------------------------------------------

  ahb0 : ahbctrl
    generic map(
      defmast => 0,                  -- default master
      split   => 0,                  -- split support
      nahbm   => 3,                  -- number of masters
      nahbs   => AHB_SLAVE_COUNT,    -- number of slaves
      fixbrst => 1                   -- support fix-length bursts
      )
    port map(
      rst  => sysrst,
      clk  => clk,
      msti => grlib_ahbmi,
      msto => grlib_ahbmo,
      slvi => ahbsi,
      slvo => ahbso
      );


  process(grlib_ahbmi, scarts_ahbmo, svga_ahbmo, disp_ahbmo)
  begin  -- process
    ahbmi.hgrant  <=  grlib_ahbmi.hgrant(0);
    ahbmi.hready  <=  grlib_ahbmi.hready;
    ahbmi.hresp   <=  grlib_ahbmi.hresp;
    ahbmi.hrdata  <=  grlib_ahbmi.hrdata;
    ahbmi.hirq    <=  grlib_ahbmi.hirq(MAX_AHB_IRQ-1 downto 0);

    for i in 2 to grlib_ahbmo'length - 1 loop
      grlib_ahbmo(i) <= ahbm_none;
    end loop;

    grlib_ahbmo(0).hbusreq  <=  scarts_ahbmo.hbusreq;
    grlib_ahbmo(0).hlock    <=  scarts_ahbmo.hlock;
    grlib_ahbmo(0).htrans   <=  scarts_ahbmo.htrans;
    grlib_ahbmo(0).haddr    <=  scarts_ahbmo.haddr;
    grlib_ahbmo(0).hwrite   <=  scarts_ahbmo.hwrite;
    grlib_ahbmo(0).hsize    <=  scarts_ahbmo.hsize;
    grlib_ahbmo(0).hburst   <=  scarts_ahbmo.hburst;
    grlib_ahbmo(0).hprot    <=  scarts_ahbmo.hprot;
    grlib_ahbmo(0).hwdata   <=  scarts_ahbmo.hwdata;
    grlib_ahbmo(0).hirq     <=  (others => '0');
    grlib_ahbmo(0).hconfig  <=  AMBA_MASTER_CONFIG;
    grlib_ahbmo(0).hindex   <=  0;

    grlib_ahbmo(1)          <=  svga_ahbmo;
	grlib_ahbmo(2)			<=  disp_ahbmo;
  end process;


	-----------------------------------------------------------------------------
	-- AMBA AHB/APB Bridge
	-----------------------------------------------------------------------------

  apb_bridge : apbctrl
    generic map(
      hindex  => 0,
      haddr   => 16#F00#,
      hmask   => 16#fff#,
      nslaves => APB_SLAVE_COUNT
      )
    port map(
      rst  => sysrst,
      clk  => clk,
      ahbi => ahbsi,              -- from master to bridge
      ahbo => apb_bridge_ahbso,   -- from bridge to master
      apbi => apbi,               -- from bridge to slaves
      apbo => apbo                -- from slaves to bridge
      );


	-----------------------------------------------------------------------------
	-- SDRAM controller
	-----------------------------------------------------------------------------
  
  sdctrl_inst : sdctrl
  generic map
  (
    -- index of ahb slave (0 is already assigned by the APB master)
    hindex => 1,
    -- AHB address
    haddr => 16#E00#,
    -- AHB mask (determines size of the address space the component can utilize)
    hmask => 16#F80#,
    -- mapping of SDCFG register (here: position 0x000 + AHB i/o base address)
    ioaddr => 16#000#,
    -- send no initialization command sequence on reset release
    pwron => 0,
    -- bdrive & vdrive active low (default
    oepol => 0,
    -- use 32 bit mode
    sdbits => 32,
    -- using inverted clock mode can help reaching timing requirements, but limits the sdclk to 40-50MHz
    invclk => 0,
    -- use 8-word burst for reading
    pageburst => 0
  )
  port map
  (
    rst => syncrst,
    clk => clk,
    ahbsi => ahbsi,
    ahbso => sdram_ahbso,
    sdi => sdi,
    sdo => sdo
  );
	

  -- sdram address
  sa(14 downto 0) <= sdo.address(16 downto 2);
  -- clock enable (active High)
  sdcke <= sdo.sdcke(0);
  -- chip select (active Low)
  sdcsn <= sdo.sdcsn(0);
  -- sdram clock
  sdclk <= clk;
  -- row address strobe
  sdrasn <= sdo.rasn;
  -- column address strobe
  sdcasn <= sdo.casn;
  -- write enable
  sdwen <= sdo.sdwen;
  -- data mask (data lines = DQ lines), when high supresses i/o data
  -- only first 4 strobes used for 32 bit mode
 -- sddqm <= sdo.dqm(3 downto 0);
  sddqm(3) <= sdo.dqm(0);
  sddqm(2) <= sdo.dqm(1);
  sddqm(1) <= sdo.dqm(2);
  sddqm(0) <= sdo.dqm(3);
  
  -- vectored iopad using vbdrive for controlling SDRAM data bus access
  sd_pad : iopadvv
  generic map
  (
    width => 32
  )
  port map
  (
    sd(31 downto 0),
    sdo.data(31 downto 0),
    sdo.vbdrive(31 downto 0),
    sdi.data(31 downto 0)
  );


  process(apb_bridge_ahbso, sdram_ahbso)
  begin  -- process
    ahbso    <= (others => ahbs_none);
    ahbso(0) <= apb_bridge_ahbso;
    ahbso(1) <= sdram_ahbso;
  end process;


	-----------------------------------------------------------------------------
	-- SVGA controller (LCD)
	-----------------------------------------------------------------------------
  
  svgactrl0 : svgactrl
    generic map
    (
      pindex => 0,
      paddr => 16#001#,
      pmask => 16#fff#,
      hindex => 1,
      memtech => 7
    )
    port map
    (
      rst => syncrst,
      clk => clk,
      vgaclk => vga_clk_int,
      apbi => apbi,
      apbo => apbo(0),
      vgao => vgao,
      ahbi => grlib_ahbmi,
      ahbo => svga_ahbmo,
      clk_sel => vga_clk_sel
    );  

    vga_clk_sel <= (others => '0');	
    ltm_hd <= vgao.hsync;
    ltm_vd <= vgao.vsync;
    ltm_r <= vgao.video_out_r(7 downto 0);
    ltm_g <= vgao.video_out_g(7 downto 0);
    ltm_b <= vgao.video_out_b(7 downto 0);
    ltm_nclk <= vga_clk_int;    
    ltm_den <= vgao.blank;
    ltm_grest <= '1';
  

	-----------------------------------------------------------------------------
	-- I2C MASTER / Extension Module
	-----------------------------------------------------------------------------

	is2c0 : i2cmaster
		port map
		(
			clk	=>	clk,
			rst	=>	syncrst,
			
			extsel     => i2c_config_sel,			
			exti       => exti,
			
			i2co	=>	i2co_pin
		);

	-- I2C output pins
	i2c_scl <= i2co_pin.scl;
	i2c_sda <= i2co_pin.sda;
	
	--i2c_scl_dbg <= i2co_pin.scl;
	--i2c_sda_dbg <= i2co_pin.sda;
	
	--i2c_trigger <= i2c_config_sel;


	-----------------------------------------------------------------------------
	-- BUTTONS / Extension Module
	-----------------------------------------------------------------------------

	but0 : buttons
		port map
		(
			rst			=> syncrst,
			clk			=> clk,
			extsel	=> buttons_config_sel,
			exti		=> exti,
			exto		=> buttons_exto,
			
			key3		=> key3,
			key2		=> key2,
			key1		=> key1,

			sw17		=> sw17,
			sw16		=> sw16,
			sw15		=> sw15,
			sw14		=> sw14,
			sw13		=> sw13,
			sw12		=> sw12,
			sw11		=> sw11,
			sw10		=> sw10,
			sw9			=> sw9,
			sw8			=> sw8,
			sw7			=> sw7,
			sw6			=> sw6,
			sw5			=> sw5,
			sw4			=> sw4,
			sw3			=> sw3,
			sw2			=> sw2,
			sw1			=> sw1,
			sw0			=> sw0
		);


	-----------------------------------------------------------------------------
	-- HARDWARE MULTIPLIER
	-----------------------------------------------------------------------------

	mult0: multiplier
		port map
		(
			rst			=> syncrst,
			clk			=> clk,
			extsel	=> mult_config_sel,
			exti		=> exti,
			exto		=> mult_exto
		);


	-----------------------------------------------------------------------------
	-- DISPLAY controller
	-----------------------------------------------------------------------------
	
  dispctrl0 : dispctrl
    generic map
    (
			hindex => 2
    )
    port map
    (
			ahbready_dbg => ahbready_dbg,
			rst => syncrst,
			clk => clk,

			extsel => disp_config_sel,
			exti => exti,
			exto => disp_exto,

			ahbi => grlib_ahbmi,
			ahbo => disp_ahbmo,
			fval => disp_fval,
			rdaddress => rdaddress_sig,
			rddata => q_sig,
			blockrdy => pxReady_sync,
			--blockrdy => blockrdy, --dbg
			
			init_ready    => hw_initialized		-- HARI: signal by sw-extension AFTER i2c init
    );
	
	
	-----------------------------------------------------------------------------
	-- DP RAM for storing ONE LINE OF RGB DATA
	-----------------------------------------------------------------------------
	
	dp_pixelram_inst : dp_pixelram
	PORT MAP
	(
		data     	=> data_sig,
		rdaddress	=> rdaddress_sig,
		rdclock		=> clk,
		wraddress	=> wraddress_sig,
		wrclock		=> clk_pixel,
		wren			=> wren_sig,
		q					=> q_sig
	);


	-----------------------------------------------------------------------------
	--- Kamera control
	-----------------------------------------------------------------------------
	camctrl0: kameractrl
		port map (
			rst					=> syncrst,
			clk					=> clk,
			extsel			=> cam_config_sel,
			exti				=> exti,
			exto				=> cam_exto,

			yR_fac			=> yR_fac,
			yG_fac			=> yG_fac,
			yB_fac			=> yB_fac,
			yMin				=> yMin,
			yMax				=> yMax,
		
			cbR_fac			=> cbR_fac,
			cbG_fac			=> cbG_fac,
			cbB_fac			=> cbB_fac,
			cbMin				=> cbMin,
			cbMax				=> cbMax,
		
			crR_fac			=> crR_fac,
			crG_fac			=> crG_fac,
			crB_fac			=> crB_fac,
			crMin				=> crMin,
			crMax				=> crMax,

			output_mode	=> output_mode
    );
	-----------------------------------------------------------------------------
	--- Kamera readout
	-----------------------------------------------------------------------------
	
  cam0 : kamera
		generic map
		(
			FILTERADDRLEN	=> TPRAM_ADDRLEN,
			FILTERDATALEN	=> TPRAM_DATALEN
		)
    port map
    (
			-- DEBUG
			--camstate					=> camstate,
			bb_rdreq_dbg			=> rdreq_dbg,
			bb_wrreq_dbg			=> wrreq_dbg,
			bb_clearfifo_dbg	=> clearfifo_dbg,


			rst				=> cam_syncrst,
			clk				=> clk_pixel,
			fval			=> cam_fval_sync,
			lval			=> cam_lval_sync,
			pixdata		=> cam_pixdata_sync,
			
			dp_data		=> data_sig,
			dp_wren		=> wren_sig,
			dp_wraddr	=> wraddress_sig,

			pixelburstReady => pxReady_sig,

			yR_fac			=> yR_fac,
			yG_fac			=> yG_fac,
			yB_fac			=> yB_fac,
			yMin				=> yMin,
			yMax				=> yMax,
		
			cbR_fac			=> cbR_fac,
			cbG_fac			=> cbG_fac,
			cbB_fac			=> cbB_fac,
			cbMin				=> cbMin,
			cbMax				=> cbMax,
		
			crR_fac			=> crR_fac,
			crG_fac			=> crG_fac,
			crB_fac			=> crB_fac,
			crMin				=> crMin,
			crMax				=> crMax,

			output_mode	=> output_mode,

			init_ready => hw_initialized
    ); 
	
	cam_trigger <= '0';		 		-- INVERT_TRIGGER must be set by i2cconfig(reg 0x0B) when this pin is LOW
	cam_resetN	<= syncrst;			-- disable reset for camera
	
	
	-- debugging only
	clk_pixel_dbg <= clk_pixel;
	cam_fval_dbg  <= cam_fval_sync;
	cam_lval_dbg  <= cam_lval_sync;
	--cam_pixdata_dbg <= cam_pixdata_sync;	
	--cam_resetN_dbg <= syncrst;		
	blockrdy_dbg <= pxReady_sig;
	--whichLine_top_dbg <= whichLine_sig;
--	wren_sig_dbg <= wren_sig;
	
	-----------------------------------------------------------------------------
	-- Scarts extension modules
	-----------------------------------------------------------------------------
    
  dis7seg_unit: ext_dis7seg
    generic map (
      DIGIT_COUNT => 8,
      MULTIPLEXED => 0)
    port map(
      clk        => clk,
      extsel     => dis7segsel,
      exti       => exti,
      exto       => dis7segexto,
      digits     => digits,
      DisEna     => open,
      PIN_select => open
      );


  counter_unit: ext_counter
    port map(
      clk        => clk,
      extsel     => counter_segsel,
      exti       => exti,
      exto       => counter_exto
      );

  aux_uart_unit : ext_miniUART
    port map (
      clk    => clk,
      extsel => aux_uart_sel,
      exti   => exti,
      exto   => aux_uart_exto,
      RxD    => aux_uart_rx,
      TxD    => aux_uart_tx);
  
  comb : process(scarts_o, debugo_if, D_RxD, dis7segexto, counter_exto, aux_uart_exto, buttons_exto, cam_exto, mult_exto, disp_exto)  --extend!
    variable extdata : std_logic_vector(31 downto 0);
  begin   
    exti.reset    <= scarts_o.reset;
    exti.write_en <= scarts_o.write_en;
    exti.data     <= scarts_o.data;
    exti.addr     <= scarts_o.addr;
    exti.byte_en  <= scarts_o.byte_en;

    dis7segsel <= '0';
    counter_segsel <= '0';
    aux_uart_sel <= '0';
		i2c_config_sel <= '0';
		hw_initialized <= '0'; 
		buttons_config_sel <= '0';
		cam_config_sel <= '0';
		disp_config_sel <= '0';
		mult_config_sel <= '0';
    
		if scarts_o.extsel = '1' then
			case scarts_o.addr(14 downto 5) is
				when "1111110111" => -- (-288)
					--DIS7SEG Module
					dis7segsel <= '1';
				
				when "1111110110" => -- (-320)
					--Counter Module
					counter_segsel <= '1';
				
				when "1111110101" => -- (-352)
					-- AUX UART
					aux_uart_sel <= '1';
				
				when "1111110100" => -- (-384)
					-- I2C config
					i2c_config_sel <= '1';
				
				when "1111110011" => -- (-416)
					-- HW INIT config
					hw_initialized <= '1';
				
				when "1111110010" => -- (-448)
					-- BUTTONS config 
					buttons_config_sel <= '1';
				
				when "1111110001" => -- (-480)
					-- CAMCTRL config 
					cam_config_sel <= '1';
				
				when "1111110000" => -- (-512)
					-- DISPCTRL config 
					disp_config_sel <= '1';
				
				when "1111101111" => -- (-544)
					-- MULTIPLIER config 
					mult_config_sel <= '1';
				
				when others =>
					null;
			end case;
		end if;
    
    extdata := (others => '0');
    for i in extdata'left downto extdata'right loop
      extdata(i) := dis7segexto.data(i) or counter_exto.data(i) or aux_uart_exto.data(i) or buttons_exto.data(i) or cam_exto.data(i) or disp_exto.data(i) or mult_exto.data(i); 
    end loop;

    scarts_i.data <= (others => '0');
    scarts_i.data <= extdata;
    scarts_i.hold <= '0';
    scarts_i.interruptin <= (others => '0');
    

    --Debug interface
    D_TxD             <= debugo_if.D_TxD;
    debugi_if.D_RxD   <= D_RxD;
  end process;


	-- process to divide clk to get proper camera pixel clock
	process(cam_counter)
	begin

		cam_counter_next <= cam_counter + 1;
		cam_pll_input_sig <= '1';

		if(cam_counter < 2)
		then
			cam_pll_input_sig <= '0';
		elsif(cam_counter = 3)
		then
			cam_pll_input_sig <= '1';
			cam_counter_next <= 0;
		end if;
	end process;

	-----------------------------------------------------------------------------
	-- Clocked signals
	-----------------------------------------------------------------------------
  
  reg : process(clk)
  begin
    if rising_edge(clk) then
      syncrst <= rst;
			cam_counter <= cam_counter_next;
			cam_pll_input <= cam_pll_input_sig;	-- pll-feed TO camera
    end if;
  end process;

end behaviour;

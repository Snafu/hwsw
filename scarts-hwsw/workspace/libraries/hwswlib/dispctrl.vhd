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
use ieee.numeric_std.all;

library grlib;
use grlib.amba.all;
use grlib.stdlib.all;
use grlib.devices.all;

library gaisler;
use gaisler.misc.all;

library work;
use work.hwswlib.all;
use work.scarts_pkg.all;
 
 
entity dispctrl is

  generic (
    hindex      : integer := 0;
    hirq        : integer := 0
  );
  
  port (
		ahbready_dbg	: out std_logic;
    rst     	  	: in std_logic;           -- Synchronous reset
    clk     	  	: in std_logic;

		extsel				: in	std_logic;
		exti					: in  module_in_type;
		exto					: out module_out_type;

		ahbi					: in  ahb_mst_in_type;
    ahbo					: out ahb_mst_out_type;
		fval					: in std_logic;
		rdaddress 		: out std_logic_vector(8 downto 0);
		rddata    		: in std_logic_vector(31 downto 0);
		blockrdy  		: in std_logic;
	
		init_ready		: in std_logic
  );

end ;

architecture rtl of dispctrl is
  
	-- normal
	constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0000000";
	constant FIFOEND : std_logic_vector(31 downto 0) := x"E0177000";
	constant MAXCOL : integer := 800;
	constant MAXROW : integer := 480;
	
	
	-- bottomright
	--constant FIFOSTART : std_logic_vector(31 downto 0) := x"E0000640";
	--constant FIFOEND : std_logic_vector(31 downto 0) := x"E00BBE40";
	--constant MAXCOL : integer := 400;
	--constant MAXROW : integer := 240;
	
	constant COLORA : std_logic_vector(31 downto 0) := x"00FF0000";
	constant COLORB : std_logic_vector(31 downto 0) := x"0000FF00";
	constant COLORC : std_logic_vector(31 downto 0) := x"000000FF";
	constant COLORD : std_logic_vector(31 downto 0) := x"00FFFFFF";
	constant NOFACE : integer := MAXROW;

  constant REVISION : amba_version_type := 0; 
  constant VENDOR_HWSW: amba_vendor_type := 16#08#;
  constant HWSW_DISPCTRL: amba_device_type := 16#13#;


	----------------------------------------------------------------------------
	-- SCARTS extension
	----------------------------------------------------------------------------

	subtype byte is std_logic_vector(7 downto 0);
	type register_set is array (0 to 11) of byte;

	constant STATUSREG_CUST : integer := 1;
	constant CONFIGREG_CUST : integer := 3;

	-- 001
	constant REG_LEFTL			: integer := 4;
	constant REG_LEFTH			: integer := 5;
	constant REG_TOPL				: integer := 6;
	constant REG_TOPH				: integer := 7;

	-- 010
	constant REG_RIGHTL			: integer := 8;
	constant REG_RIGHTH			: integer := 9;
	constant REG_BOTTOML		: integer := 10;
	constant REG_BOTTOMH		: integer := 11;

	type reg_type is record
	  ifacereg		:	register_set;
	end record;

	signal reg_next : reg_type;
	signal reg : reg_type := 
	  (
	    ifacereg => (others => (others => '0'))
	  );
	signal rstint : std_ulogic;


	----------------------------------------------------------------------------
	-- DISPCTRL
	----------------------------------------------------------------------------
    
	type facebox_t is record
		top					: integer range 0 to MAXROW;
		left				: integer range 0 to MAXCOL;
		bottom			: integer range 0 to MAXROW;
		right				: integer range 0 to MAXCOL;
	end record;

  type write_t is record
		address 	: std_logic_vector(31 downto 0);
		data			: std_logic_vector(31 downto 0);
  end record;
	
	type writestate_t is (WAIT_INIT, NOINIT,IDLE,STARTBLOCK,RESTART,WAITREADY,HANDLEBLOCK,FINISHBLOCK,UPDATEDPADDR);

  signal dmai	: ahb_dma_in_type;
  signal dmao	: ahb_dma_out_type;

	signal active_face, active_face_n, face, face_n : facebox_t := (top => NOFACE, left => NOFACE, bottom => NOFACE, right => NOFACE);
	
	signal writeState, writeState_n : writestate_t;
	--signal writeState, writeState_n : writestate_t := NOINIT;
	signal fval_old							: std_logic := '1';
	signal init_old, init_old_n : std_logic := '0';
	signal blockrdy_old, blockrdy_old_n : std_logic;
	signal blockCount, blockCount_n : integer range 0 to 511;
	signal output, output_n : write_t;
	signal pixeladdr, pixeladdr_n : std_logic_vector(8 downto 0) := "000000000";
	signal col, col_n : integer range 0 to MAXCOL;
	signal row, row_n : integer range 0 to MAXROW;
	signal pixeldata	: std_logic_vector(31 downto 0);
begin

  ahb_master : ahbmst generic map (hindex, hirq, VENDOR_HWSW, HWSW_DISPCTRL, 0, 3, 0)
  port map (rst, clk, dmai, dmao, ahbi, ahbo);


	----------------------------------------------------------------------------
	-- SCARTS extension
	----------------------------------------------------------------------------

  scarts_proc : process(reg, exti, extsel)
    variable v : reg_type;
		variable top : integer range 0 to 1023;
		variable left : integer range 0 to 1023;
		variable bottom : integer range 0 to 1023;
		variable right : integer range 0 to 1023;
		variable vtop : std_logic_vector(9 downto 0);
		variable vleft : std_logic_vector(9 downto 0);
		variable vbottom : std_logic_vector(9 downto 0);
		variable vright : std_logic_vector(9 downto 0);
  begin
    v := reg;
        
    -- write memory mapped addresses
    if ((extsel = '1') and (exti.write_en = '1')) then
      case exti.addr(4 downto 2) is
        when "000" =>
          if ((exti.byte_en(0) = '1') or (exti.byte_en(1) = '1')) then
            v.ifacereg(STATUSREG)(STA_INT) := '1';
            v.ifacereg(CONFIGREG)(CONF_INTA) :='0';
          else
            if ((exti.byte_en(2) = '1')) then
              v.ifacereg(2) := exti.data(23 downto 16);
            end if;
            if ((exti.byte_en(3) = '1')) then
              v.ifacereg(3) := exti.data(31 downto 24);
            end if;
          end if;

				-- TOP LEFT
        when "001" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_LEFTL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_LEFTH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_TOPL) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_TOPH) := exti.data(31 downto 24);
          end if;
				
				-- BOTTOM RIGHT
        when "010" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_RIGHTL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_RIGHTH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_BOTTOML) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_BOTTOMH) := exti.data(31 downto 24);
          end if;

        when others =>
          null;
      end case;
    end if;
    
    -- read memory mapped addresses
    exto.data <= (others => '0');
    if ((extsel = '1') and (exti.write_en = '0')) then
      case exti.addr(4 downto 2) is
        when "000" =>
          exto.data <= reg.ifacereg(3) & reg.ifacereg(2) & reg.ifacereg(1) & reg.ifacereg(0);
        
				when "001" =>
          if (reg.ifacereg(CONFIGREG)(CONF_ID) = '1') then
            exto.data <= MODULE_VER & MODULE_ID;
          else
            exto.data <= reg.ifacereg(REG_TOPH) & reg.ifacereg(REG_TOPL) & reg.ifacereg(REG_LEFTH) & reg.ifacereg(REG_LEFTL);
          end if;

        when "010" =>
        	exto.data <= reg.ifacereg(REG_BOTTOMH) & reg.ifacereg(REG_BOTTOML) & reg.ifacereg(REG_RIGHTH) & reg.ifacereg(REG_RIGHTL);

        when others =>
          null;
      end case;
    end if;
   
    -- compute status flags
    v.ifacereg(STATUSREG)(STA_LOOR) := reg.ifacereg(CONFIGREG)(CONF_LOOW);
    v.ifacereg(STATUSREG)(STA_FSS) := '0';
    v.ifacereg(STATUSREG)(STA_RESH) := '0';
    v.ifacereg(STATUSREG)(STA_RESL) := '0';
    v.ifacereg(STATUSREG)(STA_BUSY) := '0';
    v.ifacereg(STATUSREG)(STA_ERR) := '0';
    v.ifacereg(STATUSREG)(STA_RDY) := '1';

    -- set output enabled (default)
    v.ifacereg(CONFIGREG)(CONF_OUTD) := '1';
    
    -- module specific part
		vtop := reg.ifacereg(REG_TOPH)(1 downto 0) & reg.ifacereg(REG_TOPL);
		vleft := reg.ifacereg(REG_LEFTH)(1 downto 0) & reg.ifacereg(REG_LEFTL);
		vbottom := reg.ifacereg(REG_BOTTOMH)(1 downto 0) & reg.ifacereg(REG_BOTTOML);
		vright := reg.ifacereg(REG_RIGHTH)(1 downto 0) & reg.ifacereg(REG_RIGHTL);

		top := to_integer(unsigned(vtop));
		left := to_integer(unsigned(vleft));
		bottom := to_integer(unsigned(vbottom));
		right := to_integer(unsigned(vright));

		if top > MAXROW or bottom > MAXROW then
			top := MAXROW;
			bottom := MAXROW;
		end if;

		if left > MAXCOL or right > MAXCOL then
			left := MAXCOL;
			right := MAXCOL;
		end if;

		face_n.top <= top;
		face_n.left <= left;
		face_n.bottom <= bottom;
		face_n.right <= right;


    -- combine soft- and hard-reset
    rstint <= not RST_ACT;
    if exti.reset = RST_ACT or reg.ifacereg(CONFIGREG)(CONF_SRES) = '1' then
      rstint <= RST_ACT;
    end if;
    
    -- reset interrupt
    if reg.ifacereg(STATUSREG)(STA_INT) = '1' and reg.ifacereg(CONFIGREG)(CONF_INTA) ='0' then
      v.ifacereg(STATUSREG)(STA_INT) := '0';
    end if; 
    exto.intreq <= reg.ifacereg(STATUSREG)(STA_INT);

    reg_next <= v;
  end process;
 

	----------------------------------------------------------------------------
	-- Fill SDRAM
	----------------------------------------------------------------------------

  ahb_proc : process(rst,ahbi,dmai,dmao,fval,fval_old,blockrdy,writeState,pixeladdr,rddata,blockCount,pixeldata,output,blockrdy_old,init_ready,init_old,col,row,face,active_face)
		variable wout : write_t;
		variable ahbready : std_logic;
		variable start : std_logic;
		variable blocks : integer range 0 to 511;
  begin

		writeState_n <= writeState;
		blockrdy_old_n <= blockrdy;
		blocks := blockCount;
		pixeladdr_n <= pixeladdr;
		wout := output;
		start := '0';
		ahbready := dmao.ready;
		init_old_n <= init_ready;
		col_n <= col;
		row_n <= row;
		active_face_n <= active_face;

		ahbready_dbg <= ahbready;

		if writeState /= WAIT_INIT and writeState /= NOINIT and blockrdy_old /= blockrdy and blockrdy = '1' then
			blocks := blocks + 1;
		end if;

		if output.address = FIFOSTART then
				active_face_n <= face;
		end if;

		case writeState is
		
		-- wait for i2c - initialization, signaled by extension module
		when WAIT_INIT =>
			if init_old /= init_ready and init_ready = '1' then
				writeState_n <= NOINIT;
			end if;
			
		when NOINIT =>
			if rst = '1' and fval_old = '0' and fval = '1' then
				writeState_n <= IDLE;
				blockCount_n <= 0;
				wout.address := FIFOSTART;
				pixeladdr_n <= "000000000";
			end if;

		when IDLE =>
			if blocks > 0 then --dbg
				writeState_n <= STARTBLOCK;
			end if;

		when STARTBLOCK =>
			wout.data := pixeldata;
			pixeladdr_n <= pixeladdr + '1';

			writeState_n <= HANDLEBLOCK;

		when HANDLEBLOCK =>
			start := '1';
			if ahbready = '1' then
				wout.data := pixeldata;
				wout.address := output.address + 4;
				col_n <= col + 1;

				-- end of block
				--if wout.address(5 downto 2) = "0000" then
				if wout.address(6 downto 2) = "00000" then
					blocks := blocks - 1;

					writeState_n <= IDLE;
				else
					pixeladdr_n <= pixeladdr + '1';
				end if;
			end if;

		when others =>
		end case;

		if col = MAXCOL-1 then
			col_n <= 0;
			pixeladdr_n <= "000000000";
			--wout.address := wout.address + x"640"; --dbg
			if row = MAXROW-1 then
				row_n <= 0;
				wout.address := FIFOSTART;
				active_face_n <= face;
			else
				row_n <= row + 1;
			end if;
		end if;

		-- force to stay within framebuffer
		if wout.address >= FIFOEND or (fval_old = '0' and fval = '1') then
			wout.address := FIFOSTART;
			wout.data := x"00000000";
			pixeladdr_n <= "000000000";
			col_n <= 0;
			row_n <= 0;
			active_face_n <= face;
		end if;
		
		output_n <= wout;
		blockCount_n <= blocks;
		rdaddress <= pixeladdr;
		
		
		dmai.burst <= '1';
		dmai.irq <= '0';
		dmai.size <= "010";
		dmai.write <= '1';
		dmai.busy <= '0';
		dmai.address <= output.address;

		if ((row = face.top or row = face.bottom)
				and (col >= face.left and col <= face.right))
			 or
			 ((col = face.left or col = face.right)
			  and (row >= face.top and row <= face.bottom)) then
			dmai.wdata <= output.data(31 downto 24) & x"00ff00";
		else
			dmai.wdata <= output.data;
		end if;

		dmai.start <= start;
			
  end process;
  


  -----------------------------------------------------------------------------
  -- Registers in system clock domain
  -----------------------------------------------------------------------------

  reg_proc : process(rst,clk)
  begin
    if rising_edge(clk) then
			writeState <= writeState_n;
			blockrdy_old <= blockrdy_old_n;
			blockCount <= blockCount_n;
			output <= output_n;
			col <= col_n;
			row <= row_n;
			fval_old <= fval;

			face <= face_n;
			active_face <= active_face_n;
			
			reg <= reg_next;

			init_old <= init_old_n;
		end if;

    if falling_edge(clk) then
			pixeladdr <= pixeladdr_n;
			pixeldata <= rddata;
		end if;

		if rstint = RST_ACT or rst = '0' then
			for i in 0 to 3 loop
       	reg.ifacereg(i) <= (others => '0');
			end loop;

			for i in 4 to 11 loop
       	reg.ifacereg(i) <= (others => '1');
			end loop;

		end if;

		if rst = '0' then
			-- rising edge
			--writeState <= NOINIT; --dbg
			writeState <= WAIT_INIT;
			fval_old <= '1';
			blockrdy_old <= '0';
			blockCount <= 0;
			output.address <= FIFOSTART;
			output.data <= x"00FFFFFF";
			init_old <= '0';
			col <= 0;
			row <= 0;

			face.top <= NOFACE;
			face.left <= NOFACE;
			face.bottom <= NOFACE;
			face.right <= NOFACE;

			-- falling edge
			pixeladdr <= "000000000";
			pixeldata <= (others => '0');
		end if;
  end process;
end;


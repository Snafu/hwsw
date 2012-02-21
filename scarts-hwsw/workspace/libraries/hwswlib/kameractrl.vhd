library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.kameralib.all;
use work.scarts_pkg.all;

entity kameractrl is
	port (
		rst							: in	std_logic;
		clk							: in	std_logic;
		extsel					: in	std_logic;
		exti						: in  module_in_type;
		exto						: out module_out_type;

		yR_fac					: out std_logic_vector(8 downto 0);
		yG_fac					: out std_logic_vector(8 downto 0);
		yB_fac					: out std_logic_vector(8 downto 0);
		yMin						: out integer range 0 to 255;
		yMax						: out integer range 0 to 255;
		
		cbR_fac					: out std_logic_vector(8 downto 0);
		cbG_fac					: out std_logic_vector(8 downto 0);
		cbB_fac					: out std_logic_vector(8 downto 0);
		cbMin						: out integer range 0 to 255;
		cbMax						: out integer range 0 to 255;
		
		crR_fac					: out std_logic_vector(8 downto 0);
		crG_fac					: out std_logic_vector(8 downto 0);
		crB_fac					: out std_logic_vector(8 downto 0);
		crMin						: out integer range 0 to 255;
		crMax						: out integer range 0 to 255;

		output_mode			:	out	std_logic
    );
end;

architecture rtl of kameractrl is
	
	-- default DSP factors
	constant DFL_YR_FAC		: integer := 66;
	constant DFL_YG_FAC		: integer := 129;
	constant DFL_YB_FAC		: integer := 25;

	constant DFL_CBR_FAC	: integer := -38;
	constant DFL_CBG_FAC	: integer := -74;
	constant DFL_CBB_FAC	: integer := 112;

	constant DFL_CRR_FAC	: integer := 112;
	constant DFL_CRG_FAC	: integer := -94;
	constant DFL_CRB_FAC	: integer := -18;
	
	-- default bounds for SKIN color
	constant DFL_YMIN			: integer := 38;
	constant DFL_YMAX			: integer := 235;
	constant DFL_CBMIN		: integer := 94;
	constant DFL_CBMAX		: integer := 139;
	constant DFL_CRMIN		: integer := 139;
	constant DFL_CRMAX		: integer := 173;

	subtype byte is std_logic_vector(7 downto 0);
	type register_set is array (0 to 28) of byte;

	constant STATUSREG_CUST : integer := 1;
	constant CONFIGREG_CUST : integer := 3;

	-- 001
	constant REG_YRL				: integer := 4;
	constant REG_YRH				: integer := 5;
	constant REG_YGL				: integer := 6;
	constant REG_YGH				: integer := 7;

	-- 010
	constant REG_YBL				: integer := 8;
	constant REG_YBH				: integer := 9;
	constant REG_CBRL				: integer := 10;
	constant REG_CBRH				: integer := 11;
	
	-- 011
	constant REG_CBGL				: integer := 12;
	constant REG_CBGH				: integer := 13;
	constant REG_CBBL				: integer := 14;
	constant REG_CBBH				: integer := 15;
	
	-- 100
	constant REG_CRRL				: integer := 16;
	constant REG_CRRH				: integer := 17;
	constant REG_CRGL				: integer := 18;
	constant REG_CRGH				: integer := 19;

	-- 101
	constant REG_CRBL				: integer := 20;
	constant REG_CRBH				: integer := 21;
	constant REG_YMIN				: integer := 22;
	constant REG_YMAX				: integer := 23;

	-- 110
	constant REG_CBMIN			: integer := 24;
	constant REG_CBMAX			: integer := 25;
	constant REG_CRMIN			: integer := 26;
	constant REG_CRMAX			: integer := 27;

	-- 111
	constant REG_MODE				: integer := 28;

	type reg_type is record
	  ifacereg		:	register_set;
	end record;

	signal reg_next : reg_type;
	signal reg : reg_type := 
	  (
	    ifacereg => (others => (others => '0'))
	  );
	signal rstint : std_ulogic;
	
	signal yR_fac_next						: std_logic_vector(8 downto 0);
	signal yG_fac_next						: std_logic_vector(8 downto 0);
	signal yB_fac_next						: std_logic_vector(8 downto 0);
	signal yMin_next							: integer range 0 to 255;
	signal yMax_next							: integer range 0 to 255;
	
	signal cbR_fac_next						: std_logic_vector(8 downto 0);
	signal cbG_fac_next						: std_logic_vector(8 downto 0);
	signal cbB_fac_next						: std_logic_vector(8 downto 0);
	signal cbMin_next							: integer range 0 to 255;
	signal cbMax_next							: integer range 0 to 255;
	
	signal crR_fac_next						: std_logic_vector(8 downto 0);
	signal crG_fac_next						: std_logic_vector(8 downto 0);
	signal crB_fac_next						: std_logic_vector(8 downto 0);
	signal crMin_next							: integer range 0 to 255;
	signal crMax_next							: integer range 0 to 255;

	signal output_mode_next				: std_logic;
begin


	----------------------------------------------------------------------------
	-- SCARTS extension
	----------------------------------------------------------------------------

  comb : process(reg, exti, extsel)
    variable v : reg_type;
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

        when "001" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_YRL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_YRH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_YGL) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_YGH) := exti.data(31 downto 24);
          end if;

        when "010" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_YBL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_YBH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_CBRL) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_CBRH) := exti.data(31 downto 24);
          end if;

        when "011" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_CBGL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_CBGH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_CBBL) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_CBBH) := exti.data(31 downto 24);
          end if;

        when "100" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_CRRL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_CRRH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_CRGL) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_CRGH) := exti.data(31 downto 24);
          end if;

        when "101" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_CRBL) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_CRBH) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_YMIN) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_YMAX) := exti.data(31 downto 24);
          end if;

        when "110" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_CBMIN) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_CBMAX) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_CRMIN) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_CRMAX) := exti.data(31 downto 24);
          end if;

				when "111" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_MODE) := exti.data(7 downto 0);
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
            exto.data <= reg.ifacereg(REG_YGH) & reg.ifacereg(REG_YGL) & reg.ifacereg(REG_YRH) & reg.ifacereg(REG_YRL);
          end if;

        when "010" =>
        	exto.data <= reg.ifacereg(REG_CBRH) & reg.ifacereg(REG_CBRL) & reg.ifacereg(REG_YBH) & reg.ifacereg(REG_YBL);

        when "011" =>
        	exto.data <= reg.ifacereg(REG_CBBH) & reg.ifacereg(REG_CBBL) & reg.ifacereg(REG_CBGH) & reg.ifacereg(REG_CBGL);

        when "100" =>
        	exto.data <= reg.ifacereg(REG_CRGH) & reg.ifacereg(REG_CRGL) & reg.ifacereg(REG_CRRH) & reg.ifacereg(REG_CRRL);

        when "101" =>
        	exto.data <= reg.ifacereg(REG_YMAX) & reg.ifacereg(REG_YMIN) & reg.ifacereg(REG_CRBH) & reg.ifacereg(REG_CRBL);

        when "110" =>
        	exto.data <= reg.ifacereg(REG_CRMAX) & reg.ifacereg(REG_CRMIN) & reg.ifacereg(REG_CBMAX) & reg.ifacereg(REG_CBMIN);

        when "111" =>
        	exto.data <= x"000000" & reg.ifacereg(REG_MODE);

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
		yR_fac_next <= reg.ifacereg(REG_YRH)(0) & reg.ifacereg(REG_YRL);
		yG_fac_next <= reg.ifacereg(REG_YGH)(0) & reg.ifacereg(REG_YGL);
		yB_fac_next <= reg.ifacereg(REG_YBH)(0) & reg.ifacereg(REG_YBL);
		yMin_next <= to_integer(unsigned(reg.ifacereg(REG_YMIN)));
		yMax_next <= to_integer(unsigned(reg.ifacereg(REG_YMAX)));

		cbR_fac_next <= reg.ifacereg(REG_CBRH)(0) & reg.ifacereg(REG_CBRL);
		cbG_fac_next <= reg.ifacereg(REG_CBGH)(0) & reg.ifacereg(REG_CBGL);
		cbB_fac_next <= reg.ifacereg(REG_CBBH)(0) & reg.ifacereg(REG_CBBL);
		cbMin_next <= to_integer(unsigned(reg.ifacereg(REG_CBMIN)));
		cbMax_next <= to_integer(unsigned(reg.ifacereg(REG_CBMAX)));

		crR_fac_next <= reg.ifacereg(REG_CRRH)(0) & reg.ifacereg(REG_CRRL);
		crG_fac_next <= reg.ifacereg(REG_CRGH)(0) & reg.ifacereg(REG_CRGL);
		crB_fac_next <= reg.ifacereg(REG_CRBH)(0) & reg.ifacereg(REG_CRBL);
		crMin_next <= to_integer(unsigned(reg.ifacereg(REG_CRMIN)));
		crMax_next <= to_integer(unsigned(reg.ifacereg(REG_CRMAX)));


		output_mode_next <= reg.ifacereg(REG_MODE)(0);
		
    
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
	-- Set registers
	----------------------------------------------------------------------------

	clk_reg : process(rst, clk)
	begin
		if rising_edge(clk) then
      reg <= reg_next;

			yR_fac <= yR_fac_next;
			yG_fac <= yG_fac_next;
			yB_fac <= yB_fac_next;
			yMin <= yMin_next;
			yMax <= yMax_next;

			cbR_fac <= cbR_fac_next;
			cbG_fac <= cbG_fac_next;
			cbB_fac <= cbB_fac_next;
			cbMin <= cbMin_next;
			cbMax <= cbMax_next;

			crR_fac <= crR_fac_next;
			crG_fac <= crG_fac_next;
			crB_fac <= crB_fac_next;
			crMin <= crMin_next;
			crMax <= crMax_next;

			output_mode <= output_mode_next;
		end if;

		if rstint = RST_ACT or rst = '0' then
				for i in 0 to 3 loop
        	reg.ifacereg(i) <= (others => '0');
				end loop;

			-- Y-red factor
			reg.ifacereg(REG_YRL) <= std_logic_vector(to_signed(DFL_YR_FAC,9))(7 downto 0);
			reg.ifacereg(REG_YRH)(0) <= std_logic_vector(to_signed(DFL_YR_FAC,9))(8);
			-- Y-green factor
			reg.ifacereg(REG_YGL) <= std_logic_vector(to_signed(DFL_YG_FAC,9))(7 downto 0);
			reg.ifacereg(REG_YGH)(0) <= std_logic_vector(to_signed(DFL_YG_FAC,9))(8);
			-- Y-blue factor
			reg.ifacereg(REG_YBL) <= std_logic_vector(to_signed(DFL_YB_FAC,9))(7 downto 0);
			reg.ifacereg(REG_YBH)(0) <= std_logic_vector(to_signed(DFL_YB_FAC,9))(8);
			-- Y min value
			reg.ifacereg(REG_YMIN) <= std_logic_vector(to_unsigned(DFL_YMIN,8));
			-- Y max value
			reg.ifacereg(REG_YMAX) <= std_logic_vector(to_unsigned(DFL_YMAX,8));


			-- CB-red factor
			reg.ifacereg(REG_CBRL) <= std_logic_vector(to_signed(DFL_CBR_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CBRH)(0) <= std_logic_vector(to_signed(DFL_CBR_FAC,9))(8);
			-- CB-green factor
			reg.ifacereg(REG_CBGL) <= std_logic_vector(to_signed(DFL_CBG_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CBGH)(0) <= std_logic_vector(to_signed(DFL_CBG_FAC,9))(8);
			-- CB-blue factor
			reg.ifacereg(REG_CBBL) <= std_logic_vector(to_signed(DFL_CBB_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CBBH)(0) <= std_logic_vector(to_signed(DFL_CBB_FAC,9))(8);
			-- CB min value
			reg.ifacereg(REG_CBMIN) <= std_logic_vector(to_unsigned(DFL_CBMIN,8));
			-- CB max value
			reg.ifacereg(REG_CBMAX) <= std_logic_vector(to_unsigned(DFL_CBMAX,8));

			-- CR-red factor
			reg.ifacereg(REG_CRRL) <= std_logic_vector(to_signed(DFL_CRR_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CRRH)(0) <= std_logic_vector(to_signed(DFL_CRR_FAC,9))(8);
			-- CR-green factor
			reg.ifacereg(REG_CRGL) <= std_logic_vector(to_signed(DFL_CRG_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CRGH)(0) <= std_logic_vector(to_signed(DFL_CRG_FAC,9))(8);
			-- CR-blue factor
			reg.ifacereg(REG_CRBL) <= std_logic_vector(to_signed(DFL_CRB_FAC,9))(7 downto 0);
			reg.ifacereg(REG_CRBH)(0) <= std_logic_vector(to_signed(DFL_CRB_FAC,9))(8);
			-- CR min value
			reg.ifacereg(REG_CRMIN) <= std_logic_vector(to_unsigned(DFL_CRMIN,8));
			-- CR max value
			reg.ifacereg(REG_CRMAX) <= std_logic_vector(to_unsigned(DFL_CRMAX,8));

			-- color mode
			reg.ifacereg(REG_MODE) <= x"00";
		end if;
	end process;
end;

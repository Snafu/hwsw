library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library grlib;
use grlib.stdlib.signed_mul;

library work;
use work.kameralib.all;
use work.scarts_pkg.all;

entity multiplier is
	port (
		rst							: in	std_logic;
		clk							: in	std_logic;
		extsel					: in	std_logic;
		exti						: in  module_in_type;
		exto						: out module_out_type
    );
end;

architecture rtl of multiplier is

	subtype byte is std_logic_vector(7 downto 0);
	type register_set is array (0 to 15) of byte;

	constant STATUSREG_CUST : integer := 1;
	constant CONFIGREG_CUST : integer := 3;

	-- 001
	constant REG_OPA1L				: integer := 4;
	constant REG_OPA1H				: integer := 5;
	constant REG_OPA2L				: integer := 6;
	constant REG_OPA2H				: integer := 7;

	-- 010
	constant REG_OPB1L				: integer := 8;
	constant REG_OPB1H				: integer := 9;
	constant REG_OPB2L				: integer := 10;
	constant REG_OPB2H				: integer := 11;

	-- 011
	constant REG_RES1L				: integer := 12;
	constant REG_RES1H				: integer := 13;
	constant REG_RES2L				: integer := 14;
	constant REG_RES2H				: integer := 15;
	

	type reg_type is record
	  ifacereg		:	register_set;
	end record;

	signal reg_next : reg_type;
	signal reg : reg_type := 
	  (
	    ifacereg => (others => (others => '0'))
	  );
	signal rstint : std_ulogic;


	--signal opa, opa_next			: std_logic_vector(31 downto 0);
	--signal opb, opb_next			: std_logic_vector(31 downto 0);
	--signal res, res_next			: std_logic_vector(31 downto 0);
begin

	--domult: process(opa, opb)
	--begin
	--	res_next <= signed_mul(opa, opb)(31 downto 0);
	--end process;

	----------------------------------------------------------------------------
	-- SCARTS extension
	----------------------------------------------------------------------------

  comb : process(reg, exti, extsel)
    variable v : reg_type;
		variable opa, opb, result : std_logic_vector(31 downto 0);
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
            v.ifacereg(REG_OPA1L) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_OPA1H) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_OPA2L) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_OPA2H) := exti.data(31 downto 24);
          end if;

        when "010" =>
          if ((exti.byte_en(0) = '1')) then
            v.ifacereg(REG_OPB1L) := exti.data(7 downto 0);
          end if;
          if ((exti.byte_en(1) = '1')) then
            v.ifacereg(REG_OPB1H) := exti.data(15 downto 8);
          end if;
          if ((exti.byte_en(2) = '1')) then
            v.ifacereg(REG_OPB2L) := exti.data(23 downto 16);
          end if;
          if ((exti.byte_en(3) = '1')) then
            v.ifacereg(REG_OPB2H) := exti.data(31 downto 24);
          end if;

        when others =>
          null;
      end case;
    end if;
    
    -- module specific part
		--opa_next <= reg.ifacereg(REG_OPA2H) & reg.ifacereg(REG_OPA2L) & reg.ifacereg(REG_OPA1H) & reg.ifacereg(REG_OPA1L); 
		--opb_next <= reg.ifacereg(REG_OPB2H) & reg.ifacereg(REG_OPB2L) & reg.ifacereg(REG_OPB1H) & reg.ifacereg(REG_OPB1L); 

		opa := reg.ifacereg(REG_OPA2H) & reg.ifacereg(REG_OPA2L) & reg.ifacereg(REG_OPA1H) & reg.ifacereg(REG_OPA1L); 
		opb := reg.ifacereg(REG_OPB2H) & reg.ifacereg(REG_OPB2L) & reg.ifacereg(REG_OPB1H) & reg.ifacereg(REG_OPB1L); 
		result := signed_mul(opa, opb)(31 downto 0);
    
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
            exto.data <= reg.ifacereg(REG_OPA2H) & reg.ifacereg(REG_OPA2L) & reg.ifacereg(REG_OPA1H) & reg.ifacereg(REG_OPA1L);
          end if;

        when "010" =>
        	exto.data <= reg.ifacereg(REG_OPB2H) & reg.ifacereg(REG_OPB2L) & reg.ifacereg(REG_OPB1H) & reg.ifacereg(REG_OPB1L);

        when "011" =>
        	--exto.data <= res;
        	exto.data <= result;

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

	clk_reg : process(rst, clk, rstint)
	begin
		if rising_edge(clk) then
      reg <= reg_next;

			--opa <= opa_next;
			--opb <= opb_next;
			--res <= res_next;
		end if;

		if rstint = RST_ACT or rst = '0' then
				for i in 0 to 15 loop
        	reg.ifacereg(i) <= (others => '0');
				end loop;

				--opa <= (others => '0');
				--opb <= (others => '0');
				--res <= (others => '0');
		end if;
	end process;
end;

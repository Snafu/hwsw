library ieee;
use ieee.std_logic_1164.all;

use work.scarts_pkg.all;

library hwswlib;
use work.hwswlib.all;

entity buttons is
	port (
		rst				: in std_logic;           -- Synchronous reset
		clk				: in std_logic;
		
		extsel		: in	std_logic;
		exti			: in  module_in_type;
		exto			: out module_out_type;
		
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
		sw0				: in std_logic
		);
end;

architecture behaviour of buttons is

subtype byte is std_logic_vector(7 downto 0);
type register_set is array (0 to 7) of byte;

constant STATUSREG_CUST : integer := 1;
constant CONFIGREG_CUST : integer := 3;

constant KEYS      			: integer := 4;
constant SW_LOW 		    : integer := 5;
constant SW_HIGH        : integer := 6;
constant SW_EXTRA       : integer := 7;

type reg_type is record
  ifacereg		:	register_set;
end record;


signal r_next : reg_type;
signal r : reg_type := 
  (
    ifacereg => (others => (others => '0'))
  );
  
signal rstint : std_ulogic;

begin


  comb : process(r, exti, extsel, key1, key2, key3, sw0, sw1, sw2, sw3, sw4, sw5, sw6, sw7, sw8, sw9, sw10, sw11, sw12, sw13, sw14, sw15, sw16, sw17)
    variable v : reg_type;
  begin
    v := r;
        
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
        --  if ((exti.byte_en(0) = '1')) then
        --    v.ifacereg(4) := exti.data(7 downto 0);
        --  end if;
        --  if ((exti.byte_en(1) = '1')) then
        --    v.ifacereg(5) := exti.data(15 downto 8);
        --  end if;
        --  if ((exti.byte_en(2) = '1')) then
        --    v.ifacereg(6) := exti.data(23 downto 16);
        --  end if;
        --  if ((exti.byte_en(3) = '1')) then
        --    v.ifacereg(7) := exti.data(31 downto 24);
        --  end if;
        when others =>
          null;
      end case;
    end if;
    
    -- read memory mapped addresses
    exto.data <= (others => '0');
    if ((extsel = '1') and (exti.write_en = '0')) then
      case exti.addr(4 downto 2) is
        when "000" =>
          exto.data <= r.ifacereg(3) & r.ifacereg(2) & r.ifacereg(1) & r.ifacereg(0);
        when "001" =>
          if (r.ifacereg(CONFIGREG)(CONF_ID) = '1') then
            exto.data <= MODULE_VER & MODULE_ID;
          else
            exto.data <= r.ifacereg(SW_EXTRA) & r.ifacereg(SW_HIGH) & r.ifacereg(SW_LOW) & r.ifacereg(KEYS);
          end if;
        when others =>
          null;
      end case;
    end if;
   
    -- compute status flags
    v.ifacereg(STATUSREG)(STA_LOOR) := r.ifacereg(CONFIGREG)(CONF_LOOW);
    v.ifacereg(STATUSREG)(STA_FSS) := '0';
    v.ifacereg(STATUSREG)(STA_RESH) := '0';
    v.ifacereg(STATUSREG)(STA_RESL) := '0';
    v.ifacereg(STATUSREG)(STA_BUSY) := '0';
    v.ifacereg(STATUSREG)(STA_ERR) := '0';
    v.ifacereg(STATUSREG)(STA_RDY) := '1';

    -- set output enabled (default)
    v.ifacereg(CONFIGREG)(CONF_OUTD) := '1';
    
    -- module specific part
		v.ifacereg(KEYS)(1) := key1;
		v.ifacereg(KEYS)(2) := key2;
		v.ifacereg(KEYS)(3) := key3;

		v.ifacereg(SW_LOW)(0) := sw0;
		v.ifacereg(SW_LOW)(1) := sw1;
		v.ifacereg(SW_LOW)(2) := sw2;
		v.ifacereg(SW_LOW)(3) := sw3;
		v.ifacereg(SW_LOW)(4) := sw4;
		v.ifacereg(SW_LOW)(5) := sw5;
		v.ifacereg(SW_LOW)(6) := sw6;
		v.ifacereg(SW_LOW)(7) := sw7;

		v.ifacereg(SW_HIGH)(0) := sw8;
		v.ifacereg(SW_HIGH)(1) := sw9;
		v.ifacereg(SW_HIGH)(2) := sw10;
		v.ifacereg(SW_HIGH)(3) := sw11;
		v.ifacereg(SW_HIGH)(4) := sw12;
		v.ifacereg(SW_HIGH)(5) := sw13;
		v.ifacereg(SW_HIGH)(6) := sw14;
		v.ifacereg(SW_HIGH)(7) := sw15;

		v.ifacereg(SW_EXTRA)(0) := sw16;
		v.ifacereg(SW_EXTRA)(1) := sw17;
    
    -- combine soft- and hard-reset
    rstint <= not RST_ACT;
    if exti.reset = RST_ACT or r.ifacereg(CONFIGREG)(CONF_SRES) = '1' then
      rstint <= RST_ACT;
    end if;
    
    -- reset interrupt
    if r.ifacereg(STATUSREG)(STA_INT) = '1' and r.ifacereg(CONFIGREG)(CONF_INTA) ='0' then
      v.ifacereg(STATUSREG)(STA_INT) := '0';
    end if; 
    exto.intreq <= r.ifacereg(STATUSREG)(STA_INT);

    r_next <= v;
  end process;

  
  reg : process(clk)
  begin
    if rising_edge(clk) then 
      if rstint = RST_ACT then
        r.ifacereg <= (others => (others => '0'));
      else
        r <= r_next;
      end if;
    end if;
  end process;


end behaviour;

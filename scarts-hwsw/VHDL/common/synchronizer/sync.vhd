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

entity sync is
  generic
  (
    SYNC_STAGES : integer range 2 to integer'high;
    RESET_VALUE : std_logic
  );
  port
  (
    sys_clk : in std_logic;
    sys_res_n : in std_logic;
    data_in : in std_logic;
    data_out : out std_logic
  );
end entity sync;

library ieee;
use ieee.std_logic_1164.all;

entity vectorsync is
  generic
  (
    SYNC_STAGES : integer range 2 to integer'high;
    RESET_VALUE : std_logic;
		VECTOR_LENGTH	: integer range 2 to integer'high
  );
  port
  (
    sys_clk : in std_logic;
    sys_res_n : in std_logic;
    data_in : in std_logic_vector(VECTOR_LENGTH-1 downto 0);
    data_out : out std_logic_vector(VECTOR_LENGTH-1 downto 0)
  );
end entity vectorsync;


library ieee;
use ieee.std_logic_1164.all;

entity nsync is
  generic
  (
    SYNC_STAGES : integer range 2 to integer'high;
    RESET_VALUE : std_logic
  );
  port
  (
    sys_clk : in std_logic;
    sys_res_n : in std_logic;
    data_in : in std_logic;
    data_out : out std_logic
  );
end entity nsync;

library ieee;
use ieee.std_logic_1164.all;

entity nvectorsync is
  generic
  (
    SYNC_STAGES : integer range 2 to integer'high;
    RESET_VALUE : std_logic;
		VECTOR_LENGTH	: integer range 2 to integer'high
  );
  port
  (
    sys_clk : in std_logic;
    sys_res_n : in std_logic;
    data_in : in std_logic_vector(VECTOR_LENGTH-1 downto 0);
    data_out : out std_logic_vector(VECTOR_LENGTH-1 downto 0)
  );
end entity nvectorsync;

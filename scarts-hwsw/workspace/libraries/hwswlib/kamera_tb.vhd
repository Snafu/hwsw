library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

--use work.scarts_pkg.all;

library work;
use work.kameralib.all;

entity kamera_tb is

end kamera_tb;

architecture sim of kamera_tb is
      signal clk        : std_logic;
      signal rst        : std_logic;
      signal cam_pixclk : std_logic;
      signal cam_fval   : std_logic; 
      signal cam_lval   : std_logic;
      signal cam_pixdata: std_logic_vector(11 downto 0);
      --signal cam_sram_data : std_logic_vector(15 downto 0);
      --signal cam_sram_ctrl : sram_ctrl_t;
      
      signal data_sig : std_logic_vector(31 downto 0);
      signal wren_sig : std_logic;
      signal wraddress_sig : std_logic_vector(8 downto 0);
      signal pxReady_sig : std_logic;
begin

	kamerasim: kamera
	port map
    (
			rst			=> rst,
			clk			=> clk,
			pixclk		=> cam_pixclk,
			fval			=> cam_fval,
			lval			=> cam_lval,
			pixdata		=> cam_pixdata,
			--sram_ctrl	=> cam_sram_ctrl,
			--sram_data	=> cam_sram_data,
			
			dp_data		=> data_sig,
			dp_wren		=> wren_sig,
			dp_wraddr	=> wraddress_sig,
			pixelburstReady => pxReady_sig
    ); 
		
	process
	begin
		clk <= '0';
		rst <= '0';
		wait for 10 ns;
		rst <= '1';

		loop 
			wait for 1 ns;
			clk <= '1';       
			wait for 1 ns;
			clk <= '0';
		end loop;

	end process;
	
	process
	begin		
		loop
			cam_pixclk <= '0';
		  wait for 2500 ps;
		  cam_pixclk <= '1';
		  wait for 2500 ps;
		  cam_pixclk <= '0';
		 end loop;
	end process;
	
	process
	  begin

      cam_fval <= '0';
      cam_lval <= '0';
			cam_pixdata <= (others => '0');

			wait for 50 ns;
	    
	    for frame in 0 to 100 loop
	     wait for 5 ns;
	     cam_fval <= '1';
	     wait for 5 ns;
	     
	     for line in 0 to 480 loop
	      cam_lval <= '1';
	      
	     	for row in 0 to 800 loop
					cam_pixdata <= cam_pixdata + "10000";
	       	wait for 5 ns;  
	      end loop;

        cam_lval <= '0';
        wait for 60 ns;
        
	    end loop;
     cam_fval <= '0';
	   end loop;
	   
	  end process;
	
	
end;

onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/grlib_ahbmi
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/dmao
add wave -noupdate -color Tan -format Logic /top_tb/top_1/dispctrl0/blockrdy
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/dmao.haddr
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/dmao.rdata
add wave -noupdate -color Gold -format Logic /top_tb/top_1/dispctrl0/dmai.start
add wave -noupdate -color Magenta -format Logic /top_tb/top_1/dispctrl0/dmao.ready
add wave -noupdate -format Logic /top_tb/top_1/disp_ahbmo.hbusreq
add wave -noupdate -format Literal /top_tb/top_1/disp_ahbmo.htrans
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/disp_ahbmo.haddr
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/disp_ahbmo.hwdata
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/rdaddress
add wave -noupdate -format Logic /top_tb/clk
add wave -noupdate -format Literal /top_tb/top_1/dispctrl0/writestate
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dp_pixelram_inst/q
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dp_pixelram_inst/rdaddress
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4754822 ps} 0}
configure wave -namecolwidth 186
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {4622235 ps} {4935999 ps}

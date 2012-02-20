onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider Testbench
add wave -noupdate -format Logic /top_tb/rst
add wave -noupdate -format Logic /top_tb/clk
add wave -noupdate -format Logic /top_tb/top_1/cam_pixclk
add wave -noupdate -format Logic /top_tb/top_1/cam_fval
add wave -noupdate -format Logic /top_tb/top_1/cam_lval
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/cam_pixdata
add wave -noupdate -divider TOP
add wave -noupdate -divider Cam
add wave -noupdate -format Logic /top_tb/top_1/cam0/clk
add wave -noupdate -format Literal /top_tb/top_1/cam0/state
add wave -noupdate -color Orange -format Logic /top_tb/top_1/cam0/fval
add wave -noupdate -color Orange -format Logic /top_tb/top_1/cam0/lval
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/cam0/pixdata
add wave -noupdate -format Logic /top_tb/top_1/cam0/pixelburstready
add wave -noupdate -format Literal -radix unsigned /top_tb/top_1/cam0/linecount
add wave -noupdate -format Literal -radix unsigned /top_tb/top_1/cam0/colcount
add wave -noupdate -group FIFO -format Logic /top_tb/top_1/cam0/bayerbuf/clock
add wave -noupdate -group FIFO -format Logic /top_tb/top_1/cam0/bayerbuf/wrreq
add wave -noupdate -group FIFO -format Literal -radix hexadecimal /top_tb/top_1/cam0/bayerbuf/data
add wave -noupdate -group FIFO -format Logic /top_tb/top_1/cam0/bayerbuf/rdreq
add wave -noupdate -group FIFO -format Literal -radix hexadecimal /top_tb/top_1/cam0/bayerbuf/q
add wave -noupdate -expand -group {DP RAM W} -color {Cornflower Blue} -format Logic /top_tb/top_1/cam0/dp_wren
add wave -noupdate -expand -group {DP RAM W} -color {Cornflower Blue} -format Literal -radix hexadecimal /top_tb/top_1/cam0/dp_wraddr
add wave -noupdate -expand -group {DP RAM W} -color {Cornflower Blue} -format Literal -radix hexadecimal /top_tb/top_1/cam0/dp_data
add wave -noupdate -group Pixel -format Literal -radix hexadecimal /top_tb/top_1/cam0/pixel(r)
add wave -noupdate -group Pixel -format Literal -radix hexadecimal /top_tb/top_1/cam0/pixel(g)
add wave -noupdate -group Pixel -format Literal -radix hexadecimal /top_tb/top_1/cam0/pixel(b)
add wave -noupdate -group Dotmatrix -format Literal -radix hexadecimal /top_tb/top_1/cam0/dotmatrix(0)
add wave -noupdate -group Dotmatrix -format Literal -radix hexadecimal /top_tb/top_1/cam0/dotmatrix(1)
add wave -noupdate -divider Dispctrl
add wave -noupdate -format Literal /top_tb/top_1/dispctrl0/writestate
add wave -noupdate -format Logic /top_tb/top_1/dispctrl0/blockrdy
add wave -noupdate -group {DP RAM R} -color {Cornflower Blue} -format Literal -radix unsigned /top_tb/top_1/dispctrl0/rdaddress
add wave -noupdate -group {DP RAM R} -color {Cornflower Blue} -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/rddata
add wave -noupdate -color Magenta -format Logic /top_tb/top_1/dispctrl0/dmao.ready
add wave -noupdate -color Yellow -format Logic /top_tb/top_1/dispctrl0/dmai.start
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/output.address
add wave -noupdate -format Literal -radix hexadecimal /top_tb/top_1/dispctrl0/output.data
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {91087374 ps} 0}
configure wave -namecolwidth 201
configure wave -valuecolwidth 121
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
WaveRestoreZoom {90317033 ps} {92274293 ps}

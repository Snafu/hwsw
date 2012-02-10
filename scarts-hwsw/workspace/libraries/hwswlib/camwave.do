onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -format Logic /kamera_tb/kamerasim/rst
add wave -noupdate -format Logic /kamera_tb/kamerasim/clk
add wave -noupdate -format Logic /kamera_tb/kamerasim/pixclk
add wave -noupdate -format Logic /kamera_tb/kamerasim/fval
add wave -noupdate -format Logic /kamera_tb/kamerasim/lval
add wave -noupdate -format Literal -radix hexadecimal /kamera_tb/kamerasim/pixdata
add wave -noupdate -format Logic /kamera_tb/kamerasim/dp_wren
add wave -noupdate -format Literal -radix hexadecimal /kamera_tb/kamerasim/dp_wraddr
add wave -noupdate -format Literal -radix hexadecimal /kamera_tb/kamerasim/dp_data
add wave -noupdate -format Literal /kamera_tb/kamerasim/dp_cnt
add wave -noupdate -format Literal -radix hexadecimal /kamera_tb/kamerasim/dp_buf
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4068 ns} 0}
configure wave -namecolwidth 150
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
WaveRestoreZoom {0 ns} {535500 ns}

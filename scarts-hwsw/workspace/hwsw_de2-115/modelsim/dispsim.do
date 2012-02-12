vcom -work work ../VHDL/top_tb.vhd
vlib altera_mf
vmap altera_mf work

# set ALTERA_LIB_PATH /opt/altera/10.0sp1/quartus/eda/sim_lib
# vcom  -work altera_mf $ALTERA_LIB_PATH/altera_mf.vhd
# vcom  -work altera_mf $ALTERA_LIB_PATH/altera_mf_components.vhd

vsim -t ns work.top_tb 
do dispwave.do


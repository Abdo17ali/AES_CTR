# SDC for aes_ctr_top_apb
# PCLK @ 25 ns = 40 MHz

create_clock -name PCLK -period 25.0 [get_ports PCLK]

set_clock_uncertainty 0.30 [get_clocks PCLK]
set_clock_transition  0.15 [get_clocks PCLK]

set_input_delay  -clock PCLK 3.0 [get_ports PRESETn]
set_input_delay  -clock PCLK 3.0 [get_ports PADDR]
set_input_delay  -clock PCLK 3.0 [get_ports PSEL]
set_input_delay  -clock PCLK 3.0 [get_ports PENABLE]
set_input_delay  -clock PCLK 3.0 [get_ports PWRITE]
set_input_delay  -clock PCLK 3.0 [get_ports PWDATA]

set_output_delay -clock PCLK 3.0 [get_ports PRDATA]
set_output_delay -clock PCLK 3.0 [get_ports PREADY]
set_output_delay -clock PCLK 3.0 [get_ports PSLVERR]

set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PRESETn]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PADDR]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PSEL]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PENABLE]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PWRITE]
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 [get_ports PWDATA]

set_load 0.05 [get_ports PRDATA]
set_load 0.05 [get_ports PREADY]
set_load 0.05 [get_ports PSLVERR]

set_max_fanout 10 [current_design]

set_false_path -from [get_ports PRESETn]

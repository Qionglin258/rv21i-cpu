# Configuration bank voltage select (silences the CFGBVS warning)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

# 100 MHz clock
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.00 [get_ports clk]

# CPU clock = 100 MHz / 16 = 6.25 MHz: clk_div[3] routed through the global
# buffer u_bufg_cpu. Declared as a generated clock so the whole SoC is timed.
create_generated_clock -name cpu_clk -source [get_pins u_bufg_cpu/I] -divide_by 16 [get_pins u_bufg_cpu/O]

# Switches: sw[7:0] -> gpio_in[7:0], popcount input byte
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports sw]

# Manual reset on SW15: slide UP/ON = hold the core in reset
set_property PACKAGE_PIN R2 [get_ports rst_sw]
set_property IOSTANDARD LVCMOS33 [get_ports rst_sw]

# LEDs: led[3:0] = popcount result (gpio_out[11:8]), led[7] = heartbeat
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports led]

# USB-UART (FTDI), 115200 8N1: A18 = uart_tx (FPGA -> FTDI), B18 = uart_rx (FTDI -> FPGA)
set_property PACKAGE_PIN A18 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property PACKAGE_PIN B18 [get_ports uart_rx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx]

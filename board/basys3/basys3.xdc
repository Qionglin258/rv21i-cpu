## Basys 3 (XC7A35T-1CPG236C) constraints - stage 1 GPIO calc demo
## Pins follow the Digilent Basys3_Master.xdc; all 3.3V LVCMOS.

## 100 MHz oscillator
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk]

## Center push button = reset (active high, inverted in board_top)
set_property PACKAGE_PIN N17 [get_ports btnC]
set_property IOSTANDARD LVCMOS33 [get_ports btnC]

## Slide switches SW0..SW7 -> sw[0..7]
set_property PACKAGE_PIN V17 [get_ports {sw[0]}]
set_property PACKAGE_PIN V16 [get_ports {sw[1]}]
set_property PACKAGE_PIN W16 [get_ports {sw[2]}]
set_property PACKAGE_PIN W17 [get_ports {sw[3]}]
set_property PACKAGE_PIN W15 [get_ports {sw[4]}]
set_property PACKAGE_PIN V15 [get_ports {sw[5]}]
set_property PACKAGE_PIN W14 [get_ports {sw[6]}]
set_property PACKAGE_PIN W13 [get_ports {sw[7]}]

## LEDs LD0..LD7 <- led[0..7]
set_property PACKAGE_PIN U16 [get_ports {led[0]}]
set_property PACKAGE_PIN E19 [get_ports {led[1]}]
set_property PACKAGE_PIN U19 [get_ports {led[2]}]
set_property PACKAGE_PIN V19 [get_ports {led[3]}]
set_property PACKAGE_PIN W18 [get_ports {led[4]}]
set_property PACKAGE_PIN U15 [get_ports {led[5]}]
set_property PACKAGE_PIN U14 [get_ports {led[6]}]
set_property PACKAGE_PIN V14 [get_ports {led[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {sw[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

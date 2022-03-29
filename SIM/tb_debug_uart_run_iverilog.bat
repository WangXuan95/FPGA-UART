del sim.out dump.vcd
iverilog  -g2005-sv  -o sim.out  tb_debug_uart.sv  ../RTL/debug_uart.sv  ../RTL/uart_tx.sv  ../RTL/uart_rx.sv
vvp -n sim.out
del sim.out
pause
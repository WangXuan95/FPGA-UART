del sim.out dump.vcd
iverilog  -g2005-sv  -o sim.out  tb_uart_tx_uart_rx.sv  ../RTL/uart_tx.sv  ../RTL/uart_rx.sv
vvp -n sim.out
del sim.out
pause
del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_uart2axi4.v  ../RTL/uart2axi4.v  ../RTL/uart_tx.v  ../RTL/uart_rx.v
vvp -n sim.out
del sim.out
pause
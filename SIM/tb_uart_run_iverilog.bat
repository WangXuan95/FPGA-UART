del sim.out dump.vcd
iverilog  -g2001  -o sim.out  tb_uart.v  tb_axis_inc_source.v  ../RTL/uart_tx.v  ../RTL/uart_rx.v
vvp -n sim.out
del sim.out
pause
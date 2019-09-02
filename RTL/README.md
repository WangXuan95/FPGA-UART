
Verilog-UART 核心 RTL 代码
===========================
包含4种可独立使用的模块：

* **[uart_rx.sv](https://github.com/WangXuan95/Verilog-UART/blob/master/RTL/uart_rx.sv)**：**UART接收器**，见 [uart_rx 示例](https://github.com/WangXuan95/Verilog-UART/blob/master/Arty-examples/uart_rx)
* **[uart_tx.sv](https://github.com/WangXuan95/Verilog-UART/blob/master/RTL/uart_tx.sv)**：**UART发送器**，见 [uart_tx 示例](https://github.com/WangXuan95/Verilog-UART/blob/master/Arty-examples/uart_tx)
* **[axi_stream_to_uart_tx.sv](https://github.com/WangXuan95/Verilog-UART/blob/master/RTL/axi_stream_to_uart_tx.sv)**：**UART发送器(AXI-stream接口)** 示例 **略**
* **[debug_uart.sv](https://github.com/WangXuan95/Verilog-UART/blob/master/RTL/debug_uart.sv)**：**UART交互式调试器**，见 [debug_uart 示例](https://github.com/WangXuan95/Verilog-UART/blob/master/Arty-examples/debug_uart)

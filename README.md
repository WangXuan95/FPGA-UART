![语言](https://img.shields.io/badge/语言-systemverilog_(IEEE1800_2005)-CAD09D.svg) ![仿真](https://img.shields.io/badge/仿真-iverilog-green.svg) ![部署](https://img.shields.io/badge/部署-quartus-blue.svg) ![部署](https://img.shields.io/badge/部署-vivado-FF1010.svg)

中文 | [English](#en)

Verilog-UART
===========================

本库包含3种可独立使用的模块：

* **UART接收器**：[RTL/uart_rx.sv](./RTL/uart_rx.sv)
* **UART发送器**：[RTL/uart_tx.sv](./RTL/uart_tx.sv)
* **UART交互式调试器**：[RTL/debug_uart.sv](./RTL/debug_uart.sv)



# UART接收器 uart_rx

UART接收器的代码文件是 [RTL/uart_rx.sv](./RTL/uart_rx.sv) ，定义如下：

```verilog
module uart_rx #(
    parameter CLK_DIV = 434,     // UART baud rate = clk freq/CLK_DIV. for example, when clk=50MHz, CLK_DIV=434, then baud=50MHz/434=115200
    parameter PARITY  = "NONE"   // "NONE", "ODD" or "EVEN"
) (
    input  wire       rstn,
    input  wire       clk,
    // uart rx input signal
    input  wire       i_uart_rx,
    // user interface
    output reg  [7:0] rx_data,
    output reg        rx_en
);
```

其中：

- `CLK_DIV` 是分频系数，决定了 UART波特率， UART波特率 = `clk` 频率 / `CLK_DIV` 。
- `PARITY` 决定了校验位，`"NONE"`是无校验位，`"ODD"`是奇校验位，`"EVEN"`是偶校验位。
- `rstn` 是复位，在开始时让 `rstn=0` 来复位，然后让 `rstn=1` 释放复位。
- `clk` 是时钟。所有信号的采样和改变都要在 `clk` 的上升沿进行。
- `i_uart_rx` 是 UART 接收信号。
- `rx_data` 和 `rx_en` 信号：当 `rx_en=1` 时，说明模块接收到一个字节的 UART 数据，同时该字节在 `rx_data` 有效。



# UART发送器 uart_tx

UART发送器的代码文件是 [RTL/uart_tx.sv](./RTL/uart_tx.sv) ，定义如下：

```verilog
module uart_tx #(
    parameter CLK_DIV     = 434,       // UART baud rate = clk freq/CLK_DIV. for example, when clk=50MHz, CLK_DIV=434, then baud=50MHz/434=115200
    parameter PARITY      = "NONE",    // "NONE", "ODD" or "EVEN"
    parameter ASIZE       = 10,        // UART TX buffer size = 2^ASIZE bytes, Set it smaller if your FPGA doesn't have enough BRAM
    parameter DWIDTH      = 1,         // Specify width of tx_data , that is, how many bytes can it input per clock cycle
    parameter ENDIAN      = "LITTLE",  // "LITTLE" or "BIG". when DWIDTH>=2, this parameter determines the byte order of tx_data
    parameter MODE        = "RAW",     // "RAW", "PRINTABLE", "HEX" or "HEXSPACE"
    parameter END_OF_DATA = "",        // Specify a extra send byte after each tx_data. when ="", do not send this extra byte
    parameter END_OF_PACK = ""         // Specify a extra send byte after each tx_data with tx_last=1. when ="", do not send this extra byte
)(
    input  wire                rstn,
    input  wire                clk,
    // user interface
    input  wire [DWIDTH*8-1:0] tx_data,
    input  wire                tx_last,
    input  wire                tx_en,
    output wire                tx_rdy,
    // uart tx output signal
    output reg                 o_uart_tx
);
```

UART发送器内部有一个FIFO，缓存暂时未发送的数据。所以，发送数据的方式是向FIFO中写入数据。写FIFO的波形图如**图1**，其中 `tx_en` 和 `tx_rdy` 构成了握手信号，这张图中它连续向FIFO写入了5个数据，期间 `tx_en` 置1，代表持续的写入请求，前四个数据时 `tx_rdy=1`，说明它们在一个周期内就成功写入。第5个数据时 `tx_rdy=0`，说明FIFO满了，则 `tx_en` 和 `tx_data` 要持续保持直到 `tx_rdy=1` 为止，第5个数据才被成功写入。

|         ![](./figures/uart_tx.png)         |
| :----------------------------------------: |
| **图1**：向 uart_tx 模块中发送数据的波形图 |

uart_tx.sv 的其它说明：

- `CLK_DIV` 是分频系数，决定了 UART波特率， UART波特率 = `clk` 频率 / CLK_DIV 。
- `PARITY` 决定了校验位，`"NONE"`是无校验位，`"ODD"` 是奇校验位，`"EVEN"` 是偶校验位。
- `DWIDTH` 决定了每个数据具有多少个字节，也就是 `tx_data` 的数据位宽，1代表1字节，2代表2字节...
- `ENDIAN` 决定了字节序：
  - `"LITTLE"`是小端序，代表数据中的低字节先发送；
  - `"BIG"`是大端序，代表数据中的高字节先发送。
- `MODE` 决定了发送模式：
  - `"RAW"` 是直接发送字节；
  - `"PRINTABLE"` 是只发送ASCII可打印字节，跳过不可打印字节；
  - `"HEX"` 是十六进制打印模式，对于一个字节 0xAB ，它实际上会转化成两个字节 "A", "B" 来发送。
  - `"HEXSPACE"` 是十六进制加空格打印模式，对于一个字节 0xAB ，它实际上会转化成三个字节 "A", "B", " " 来发送。
- `END_OF_DATA` 决定了是否在每个数据后额外加一个字节：
  - 如果让 `END_OF_DATA=""` ，则不发送额外的字节。
  - 可以让 `END_OF_DATA="\n"` ，这样每次发送完一个数据就发送一个换行。
- `END_OF_PACK` 决定了是否在 `tx_last=1` 的数据后额外加一个字节。在输入 `tx_data` 的同时，你可以令 `tx_last=1` ，这样：
  - 如果让 `END_OF_PACK=""` ，则不发送额外的字节。
  - 可以让 `END_OF_PACK="E"` ，发送完该数据时，就发送一个 "E"。
- `rstn` 是复位，在开始时让 `rstn=0` 来复位，然后让 `rstn=1` 释放复位。
- `clk` 是时钟。所有信号的采样和改变都要在 `clk` 的上升沿进行。
- `o_uart_tx` 是 UART 发送信号。




# UART交互式调试器 debug_uart

UART交互式调试器的代码文件是 [RTL/debug_uart.sv](./RTL/debug_uart.sv)，它能接收上位机的 UART 命令，完成总线读写或存储器读写，并将结果反馈给上位机。是调试存储器或SoC系统的有力工具。

debug_uart 定义如下：

```verilog
module debug_uart #(
    parameter  UART_CLK_DIV = 434, // UART baud rate = clk freq/UART_CLK_DIV. for example, when clk=50MHz, UART_CLK_DIV=434 , then baud=50MHz/434=115200
    parameter  AWIDTH       = 4,   // address width = 4bytes = 32bits
    parameter  DWIDTH       = 4,   // data width = 4bytes = 32bits
    parameter  WR_TIMEOUT   = 500, // wait for wr_rdy cycles
    parameter  RD_TIMEOUT   = 500, // wait for rd_rdy cycles
    parameter  READ_IMM     = 0    // 0: read after rd_rdy: Capture rd_data in the next clock cycle of rd_rdy=1
                                   // 1: read immediately : Capture rd_data in the clock cycle of rd_rdy=1
)(
    input  wire                rstn,
    input  wire                clk,
    // UART
    input  wire                i_uart_rx,
    output reg                 o_uart_tx,
    // bus write interface
    output reg                 wr_en,
    input  wire                wr_rdy,
    output reg  [AWIDTH*8-1:0] wr_addr,
    output reg  [DWIDTH*8-1:0] wr_data,
    // bus read  interface
    output reg                 rd_en,
    input  wire                rd_rdy,
    output reg  [AWIDTH*8-1:0] rd_addr,
    input  wire [DWIDTH*8-1:0] rd_data
);
```

debug_uart 的使用方式是：

* 通过 UART 给它发送 `addr\n` ，就可以在 bus read interface 上发起一个读请求。例如，输入 `12\n` 能发起一个 `rd_addr=0x12` 的读请求。
* 输入 `addr data\n` ，就可以在 bus write interface 上发起一个写请求。例如，输入 `12 deadbeef\n` 能发起一个 `rd_addr=0x12` 的写请求，写数据 `wr_data=0xdeadbeef` 。

读请求、写请求的波形如**图2**。注意到 `READ_IMM` 参数会决定读请求时的采样 `rd_data` 的时刻。

|                ![](./figures/debug_uart.png)                 |
| :----------------------------------------------------------: |
| 图2：写请求（左）、读请求 `READ_IMM=1`（中）、读请求 `READ_IMM=0`（右） |



# 仿真

仿真相关的文件都在 SIM 文件夹中，其中：

- tb_uart_tx_uart_rx.sv 是 uart_tx 和 uart_rx 的联合仿真代码，它把 uart_tx 和 uart_rx 的 UART 信号连起来，所以在 uart_tx 发送的数据会在 uart_rx 上接收到。
- tb_uart_tx_uart_rx_run_iverilog.bat 包含了运行 iverilog 仿真的命令。
- tb_debug_uart.sv 是针对 debug_uart 的仿真代码。
- tb_debug_uart_run_iverilog.bat 包含了运行 iverilog 仿真的命令。

使用 iverilog 进行仿真前，需要安装 iverilog ，见：[iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

然后双击 tb_uart_tx_uart_rx_run_iverilog.bat 或 tb_debug_uart_run_iverilog.bat 运行仿真，然后可以打开生成的 dump.vcd 文件查看波形。



<span id="en">Verilog-UART</span>
===========================

This repository contains 3 independent modules:

- **UART Receiver**: [RTL/uart_rx.sv](./RTL/uart_rx.sv)
- **UART Transmitter**: [RTL/uart_tx.sv](./RTL/uart_tx.sv)
- **UART Interactive Debugger**: [RTL/debug_uart.sv](./RTL/debug_uart.sv)



# UART Receiver: uart\_rx

The source file for the UART receiver is [RTL/uart_rx.sv](./RTL/uart_rx.sv) which is defined as follows:

```verilog
module uart_rx #(
    parameter CLK_DIV = 434,     // UART baud rate = clk freq/CLK_DIV. for example, when clk=50MHz, CLK_DIV=434, then baud=50MHz/434=115200
    parameter PARITY  = "NONE"   // "NONE", "ODD" or "EVEN"
) (
    input  wire       rstn,
    input  wire       clk,
    // uart rx input signal
    input  wire       i_uart_rx,
    // user interface
    output reg  [7:0] rx_data,
    output reg        rx_en
);
```

where:

- `CLK_DIV` is the clock division factor, which determines the UART baud rate, UART baud rate = `clk` frequency / `CLK_DIV` .
- `PARITY` determines the parity type, `"NONE"` is no parity, `"ODD"` is odd parity, and `"EVEN"` is even parity.
- `rstn` is reset, at the beginning let `rstn=0` to reset, then let `rstn=1` to release reset.
- `clk` is the driving clock. All signals should be changed or sampled at the rising edge of `clk`.
- `i_uart_rx` is the UART RX signal.
- `rx_data` and `rx_en` signals: `rx_en=1` means that the module has received a byte of UART data, and the byte is valid on `rx_data`.



# UART Transmitter: uart\_tx

The source file for the UART transmitter is [RTL/uart_tx.sv](./RTL/uart_tx.sv) which is defined as follows:

```verilog
module uart_tx #(
    parameter CLK_DIV     = 434,       // UART baud rate = clk freq/CLK_DIV. for example, when clk=50MHz, CLK_DIV=434, then baud=50MHz/434=115200
    parameter PARITY      = "NONE",    // "NONE", "ODD" or "EVEN"
    parameter ASIZE       = 10,        // UART TX buffer size = 2^ASIZE bytes, Set it smaller if your FPGA doesn't have enough BRAM
    parameter DWIDTH      = 1,         // Specify width of tx_data , that is, how many bytes can it input per clock cycle
    parameter ENDIAN      = "LITTLE",  // "LITTLE" or "BIG". when DWIDTH>=2, this parameter determines the byte order of tx_data
    parameter MODE        = "RAW",     // "RAW", "PRINTABLE", "HEX" or "HEXSPACE"
    parameter END_OF_DATA = "",        // Specify a extra send byte after each tx_data. when ="", do not send this extra byte
    parameter END_OF_PACK = ""         // Specify a extra send byte after each tx_data with tx_last=1. when ="", do not send this extra byte
)(
    input  wire                rstn,
    input  wire                clk,
    // user interface
    input  wire [DWIDTH*8-1:0] tx_data,
    input  wire                tx_last,
    input  wire                tx_en,
    output wire                tx_rdy,
    // uart tx output signal
    output reg                 o_uart_tx
);
```

There is a FIFO inside the UART transmitter, which buffers the data that has not yet been sent. So, the way to send data is to write data to the FIFO. The waveform of writing FIFO is shown in **Figure1**, in which `tx_en` and `tx_rdy` constitute a pair of handshake signals. In this figure, it continuously writes 5 data elements to the FIFO. During this period, `tx_en` is set to 1, which represents a continuous write request. When `tx_rdy=1` for the first four data, it means that they are successfully written. When the 5th data is sent, `tx_rdy=0`, it means that the FIFO is full, then `tx_en` and `tx_data` will continue to hold until `tx_rdy=1`, and the 5th data will be successfully written.

|                  ![](./figures/uart_tx.png)                  |
| :----------------------------------------------------------: |
| **Figure1** : waveform of writing data to the FIFO of uart_tx.sv |

Other desicriptions for uart_tx.sv :

- `CLK_DIV` is the clock division factor, which determines the UART baud rate, UART baud rate = `clk` frequency / CLK_DIV .
- `PARITY` determines the parity type, `"NONE"` is no parity, `"ODD"` is an odd parity, and `"EVEN"` is an even parity.
- `DWIDTH` determines how many bytes each data has, that is, the byte width of `tx_data`, 1 means 1 byte, 2 means 2 bytes...
- `ENDIAN` determines the endianness:
  - `"LITTLE"` means little-endian, which means that the low-order byte in the data is sent first;
  - `"BIG"` means big-endian, which means that the high byte in the data is sent first.
- `MODE` determines the send mode:
  - `"RAW"` is to send bytes directly;
  - `"PRINTABLE"` is to send only ASCII printable bytes, skip non-printable bytes;
  - `"HEX"` is the hexadecimal printing mode, for a byte 0xAB , it will actually be converted into two bytes "A", "B" to send.
  - `"HEXSPACE"` is the hexadecimal plus space printing mode, for a byte 0xAB , it will actually be converted into three bytes "A", "B", " " to send.
- `END_OF_DATA` determines whether to add an extra byte after each data, for example:
  - If let `END_OF_DATA=""` , no extra byte is sent.
  - You can set `END_OF_DATA="\n"` , so that a newline is sent every time a data is sent.
- `END_OF_PACK` determines whether to add an extra byte after the data with `tx_last=1`. While entering `tx_data`, you can set `tx_last=1`, for example:
  - If let `END_OF_PACK=""` , no extra byte is sent.
  - You can set `END_OF_PACK="E"` , so that a "E" is sent after every data with `tx_last=1`
- `rstn` is reset, at the beginning let `rstn=0` to reset, then let `rstn=1` to release reset.
- `clk` is the clock. All signals should be changed or sampled at the rising edge of `clk`.
- `o_uart_tx` is the UART TX signal.




# UART Interactive Debugger: debug\_uart

The source file of the UART interactive debugger is [RTL/debug_uart.sv](./RTL/debug_uart.sv), which can receive UART commands from the host computer, act bus read and writ actions, and feed the results back to the host computer. It is a powerful tool to debug memories or SoC systems.

debug_uart is defined as follows:

```verilog
module debug_uart #(
    parameter  UART_CLK_DIV = 434, // UART baud rate = clk freq/UART_CLK_DIV. for example, when clk=50MHz, UART_CLK_DIV=434 , then baud=50MHz/434=115200
    parameter  AWIDTH       = 4,   // address width = 4bytes = 32bits
    parameter  DWIDTH       = 4,   // data width = 4bytes = 32bits
    parameter  WR_TIMEOUT   = 500, // wait for wr_rdy cycles
    parameter  RD_TIMEOUT   = 500, // wait for rd_rdy cycles
    parameter  READ_IMM     = 0    // 0: read after rd_rdy: Capture rd_data in the next clock cycle of rd_rdy=1
                                   // 1: read immediately : Capture rd_data in the clock cycle of rd_rdy=1
)(
    input  wire                rstn,
    input  wire                clk,
    // UART
    input  wire                i_uart_rx,
    output reg                 o_uart_tx,
    // bus write interface
    output reg                 wr_en,
    input  wire                wr_rdy,
    output reg  [AWIDTH*8-1:0] wr_addr,
    output reg  [DWIDTH*8-1:0] wr_data,
    // bus read  interface
    output reg                 rd_en,
    input  wire                rd_rdy,
    output reg  [AWIDTH*8-1:0] rd_addr,
    input  wire [DWIDTH*8-1:0] rd_data
);
```

The usage of debug_uart is:

* Send `addr\n` to it via UART to start a read action on the bus read interface. For example, sending `12\n` can start a read action with `rd_addr=0x12`.
* Send `addr data\n` to it via UART to start a write action on the bus write interface. For example, sending `12 deadbeef\n` can start a write action with `rd_addr=0x12`, writing data `wr_data=0xdeadbeef`.

The waveforms of read action and write action are shown in the **Figure2** . Note that the `READ_IMM` parameter determines the moment at which `rd_data` is sampled of the read action.

|                ![](./figures/debug_uart.png)                 |
| :----------------------------------------------------------: |
| **Figure2** : write action (left), read action with `READ_IMM=1` (middle), and read action with `READ_IMM=0` (right). |



# RTL Simulation

Simulation related files are in the [SIM](./SIM) folder, where:

- [tb_uart_tx_uart_rx.sv](./SIM) is the testbench code of uart_tx and uart_rx, it connects the UART signals of uart_tx and uart_rx, so the data sent on uart_tx will be received by uart_rx.
- [tb_uart_tx_uart_rx_run_iverilog.bat](./SIM) is the command script to run iverilog simulation.
- [tb_debug_uart.sv](./SIM) is the testbench code for debug_uart.
- [tb_debug_uart_run_iverilog.bat](./SIM) is the command script to run iverilog simulation.

Before using iverilog for simulation, you need to install iverilog , see: [iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

Then double-click tb_uart_tx_uart_rx_run_iverilog.bat or tb_debug_uart_run_iverilog.bat to run the simulation, and then you can open the generated dump.vcd file to view the waveform.

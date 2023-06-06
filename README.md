![语言](https://img.shields.io/badge/语言-verilog_(IEEE1364_2001)-9A90FD.svg) ![仿真](https://img.shields.io/badge/仿真-iverilog-green.svg) ![部署](https://img.shields.io/badge/部署-quartus-blue.svg) ![部署](https://img.shields.io/badge/部署-vivado-FF1010.svg)

[English](#en) | [中文](#cn)

　

<span id="en">Verilog-UART</span>
===========================

This repository contains 3 useful modules:

* **UART Receiver**, [uart_rx.v](./RTL/uart_rx.v) , has a AXI-stream master port, which can receive UART data and output it by AXI-stream.
* **UART Transmitter**, [uart_tx.v](./RTL/uart_tx.v) , has a AXI-stream slave port, which can receive AXI-stream data and output it by UART.
* **UART to AXI4 master**, [uart2axi4.v](./RTL/uart2axi4.v) . It can receive UART commands from Host-PC, do AXI4 bus reading and writing, and feedback the results to the Host-PC. It is a powerful tool for debugging SoC systems.

Features:

- Standard AXI-stream / AXI4 interface.
- Configurable TX/RX buffer
- Configurable UART baud rate, parity bit, and stop bits
- Fractional frequency division: When the clock frequency cannot be divided by the baud rate, the cycles of each bit are different, thus rounding up a more accurate baud rate.
- Baud rate check report: During simulation, the baud rate accuracy will be printed using `$display`. If it is too imprecise, an error will be reported.

　

　

# 1. UART Receiver: uart\_rx

The code file of the UART receiver is [uart_rx.v](./RTL/uart_rx.v). This module has no sub modules.

The module definition is as follows:

```verilog
module uart_rx #(
    // clock frequency
    parameter  CLK_FREQ  = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE = 115200,       // Unit : Hz
    parameter  PARITY    = "NONE",       // "NONE", "ODD", or "EVEN"
    // RX fifo depth
    parameter  FIFO_EA   = 0             // 0:no fifo   1,2:depth=4   3:depth=8   4:depth=16  ...  10:depth=1024   11:depth=2048  ...
) (
    input  wire        rstn,
    input  wire        clk,
    // UART RX input signal
    input  wire        i_uart_rx,
    // output AXI-stream master. Associated clock = clk. 
    input  wire        o_tready,
    output reg         o_tvalid,
    output reg  [ 7:0] o_tdata,
    // report whether there's a overflow
    output reg         o_overflow
);
```

### 1.1 parameter 配置

- `CLK_FREQ` is the frequency of `clk` . User must correctly config it to get correnct baud rate.
- `BAUD_RATE` is UART baud rate.
- `PARITY` can be "NONE", "ODD", or "EVEN"
- `FIFO_EA` is for configuring RX fifo.
  - `FIFO_EA=0` : no RX fifo, the receiving byte must be accepted by user immediately.
  - `FIFO_EA=1,2` : fifo depth = 4;
  - `FIFO_EA=3` : fifo depth = 8;
  - `FIFO_EA=4` : fifo depth = 16;
  - ……
- When `FIFO_EA` is large (>8), it will be implemented by BRAM.

### 1.2 Clock and reset

`rstn` is low reset

`clk` is clock, all signals will be and should be changed at rise-edge of `clk`

### 1.3 UART signal

`i_uart_rx` is UART input signal.

### 1.4 AXI-stream master

`o_tready` , `o_tvalid` , `o_tdata` belong to a AXI-stream master.

- When `o_tvalid=1` , the valid receive byte will appear on `o_tdata`
- If user is ready to accept a received byte, let `o_tready=1`
- When `o_tvalid=1` and `o_tready=1` simultaneously, a handshake success and current data is successfully dequeued from module's internal FIFO. At next cycle, next receiving byte may appear on `o_tdata`

> :warning: If there is no receive FIFO (`FIFO_EA=0`), the module will not wait for the user to accept the current byte. As long as a byte is received, it will cause `o_tvalid=1` for one cycle, and make the byte appear on `o_tdata` .

### 1.5 `o_overflow` signal

If users frequently make ` o_tready=1` , that is, if the data is not taken away in time, the received data may be stored more and more in module's FIFO. When the FIFO overflow, the newly received bytes will be discarded, and a one-cycle-high-pulse will appear on `o_overflow` . In other cases, `o_overflow` keeps low.

### 1.6 Baud rate checking

During simulation, the module will print the time points and accuracy of the edges of each bit based on the user's configuration. If the accuracy is too poor (relative error>8%), the module will use `$error` to report an error, helping users detect configuration errors in advance.

For example, if we config `CLK_FREQ=5000000` (5MHz) , `BAUD_RATE=115200` , `PARITY="ODD"` , it will print report:

```
uart_rx :           parity = ODD
uart_rx :     clock period = 200 ns   (5000000    Hz)
uart_rx : baud rate period = 8681 ns   (115200     Hz)
uart_rx :      baud cycles = 43
uart_rx : baud cycles frac = 4
uart_rx :             __      ____ ____ ____ ____ ____ ____ ____ ____________
uart_rx :        wave   \____/____X____X____X____X____X____X____X____X____/
uart_rx :        bits   | S  | B0 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | P   |
uart_rx : time_points  t0   t1   t2   t3   t4   t5   t6   t7   t8   t9   t10
uart_rx :
uart_rx : t1 - t0 = 8681 ns (ideal)  8600 +- 200 ns (actual).   error=281 ns   relative_error=3.232%
uart_rx : t2 - t0 = 17361 ns (ideal)  17400 +- 200 ns (actual).   error=239 ns   relative_error=2.752%
uart_rx : t3 - t0 = 26042 ns (ideal)  26000 +- 200 ns (actual).   error=242 ns   relative_error=2.784%
uart_rx : t4 - t0 = 34722 ns (ideal)  34800 +- 200 ns (actual).   error=278 ns   relative_error=3.200%
uart_rx : t5 - t0 = 43403 ns (ideal)  43400 +- 200 ns (actual).   error=203 ns   relative_error=2.336%
uart_rx : t6 - t0 = 52083 ns (ideal)  52000 +- 200 ns (actual).   error=283 ns   relative_error=3.264%
uart_rx : t7 - t0 = 60764 ns (ideal)  60800 +- 200 ns (actual).   error=236 ns   relative_error=2.720%
uart_rx : t8 - t0 = 69444 ns (ideal)  69400 +- 200 ns (actual).   error=244 ns   relative_error=2.816%
uart_rx : t9 - t0 = 78125 ns (ideal)  78200 +- 200 ns (actual).   error=275 ns   relative_error=3.168%
uart_rx : t10- t0 = 86806 ns (ideal)  86800 +- 200 ns (actual).   error=206 ns   relative_error=2.368%
```

　

　

# 2. UART Transmitter: uart\_tx

The code file of the UART Transmitter is [uart_tx.v](./RTL/uart_tx.v). This module has no sub modules.

The module definition is as follows:

```verilog
module uart_tx #(
    // clock frequency
    parameter  CLK_FREQ                  = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE                 = 115200,       // Unit : Hz
    parameter  PARITY                    = "NONE",       // "NONE", "ODD", or "EVEN"
    parameter  STOP_BITS                 = 2,            // can be 1, 2, 3, 4, ...
    // AXI stream data width
    parameter  BYTE_WIDTH                = 1,            // can be 1, 2, 3, 4, ...
    // TX fifo depth
    parameter  FIFO_EA                   = 0,            // 0:no fifo   1,2:depth=4   3:depth=8   4:depth=16  ...  10:depth=1024   11:depth=2048  ...
    // do you want to send extra byte after each AXI-stream transfer or packet?
    parameter  EXTRA_BYTE_AFTER_TRANSFER = "",           // specify a extra byte to send after each AXI-stream transfer. when ="", do not send this extra byte
    parameter  EXTRA_BYTE_AFTER_PACKET   = ""            // specify a extra byte to send after each AXI-stream packet  . when ="", do not send this extra byte
) (
    input  wire                    rstn,
    input  wire                    clk,
    // input  stream : AXI-stream slave. Associated clock = clk
    output wire                    i_tready,
    input  wire                    i_tvalid,
    input  wire [8*BYTE_WIDTH-1:0] i_tdata,
    input  wire [  BYTE_WIDTH-1:0] i_tkeep,
    input  wire                    i_tlast,
    // UART TX output signal
    output reg                     o_uart_tx
);
```

### 2.2 parameter 配置

- `CLK_FREQ` is the frequency of `clk` . User must correctly config it to get correnct baud rate.
- `BAUD_RATE` is UART baud rate.
- `PARITY` can be "NONE", "ODD", or "EVEN"
- `STOP_BITS` is the number of stop bits '1'
- `BYTE_WIDTH` is the byte-width of AXI-stream slave's data (`i_tdata`)
- `FIFO_EA` is for configuring TX fifo.
  - `FIFO_EA=0` : no TX fifo. For each successful handshake of data, we must wait for the UART transmission to complete before shaking the next data.
  - `FIFO_EA=1,2` : fifo depth = 4;
  - `FIFO_EA=3` : fifo depth = 8;
  - `FIFO_EA=4` : fifo depth = 16;
  - ……
- When `FIFO_EA` is large (>8), it will be implemented by BRAM.

- `EXTRA_BYTE_AFTER_TRANSFER` is to configure whether an additional byte needs to be sent through UART every time an AXI-stream transfer (i.e. a successful handshake)
  - If you don't want to send extra bytes, just let `EXTRA_BYTE_AFTER_TRANSFER=""`
  - If you want to send additional bytes, such as the space byte " ", let  ` EXTRA_BYTE_AFTER_TRANSFER=" "`
- `EXTRA_BYTE_AFTER_PACKET` is to configure whether an additional byte needs to be sent through UART every time an AXI-stream packet (i.e. a successful handshake and `i_tlast=1`)
  - If you don't want to send extra bytes, just let `EXTRA_BYTE_AFTER_PACKET=""`
  - If you want to send additional bytes, such as the new-line byte "\n", let  ` EXTRA_BYTE_AFTER_PACKET="\n"`

### 2.2 Clock and reset

`rstn` is low reset

`clk` is clock, all signals will be and should be changed at rise-edge of `clk`

### 2.3 UART signal

`o_uart_tx` is UART output signal.

### 2.4 AXI-stream slave

`i_tready` , `i_tvalid` , `i_tdata` , `i_tdata` , `i_tkeep` , `t_tlast` belong to AXI-stream slave interface.

- `i_tready=1` means the module yet has FIFO space. `i_tready=0` means the module has no more FIFO space for accept more data.
- `i_tvalid=1` means the user want to enqueue a data to TX FIFO. Meanwhile, `i_tdata`, `i_tkeep` , `i_tlast` must valid.
- When `i_tvalid=1` and `i_tready=1` simultaneously, a handshake success, a data is successfully enqueue to FIFO.
- `i_tkeep` is byte-enable signal :
  - `i_tkeep[0]` means `i_tdata[7:0]` byte is valid, and will be send on UART, otherwise it will not be send.
  - `i_tkeep[1]` means `i_tdata[15:8]` byte is valid, and will be send on UART, otherwise it will not be send.
  - `i_tkeep[2]` means `i_tdata[23:16]` byte is valid, and will be send on UART, otherwise it will not be send.
  - ......
- `i_tlast` is the packet border indicator of AXI-stream. When sending a data, if `i_tlast=1`
  - If `EXTRA_BYTE_AFTER_PACKET` specify a extra byte, UART will send this extra byte.
  - If `EXTRA_BYTE_AFTER_PACKET=""` did not specify a extra byte, UART will not send this extra byte. In other words, at this point, `i_tlast` has no effect whether it is 0 or 1.

### 2.5 Baud rate checking

During simulation, the module will print the time points and accuracy of the edges of each bit based on the user's configuration. If the accuracy is too poor (relative error>3%), the module will use `$error` to report an error, helping users detect configuration errors in advance.

　

　

# 3. UART to AXI4 master (uart2axi4)

The code file is [RTL/uart2axi4.v](./RTL/uart2axi4.v). This module will call [uart_tx.v](./RTL/uart_tx.v) and  [uart_rx.v](./RTL/uart_rx.v)

This module is an AXI4 master that can receive UART commands from the upper computer, complete AXI4 bus reading and writing, and provide the results to the upper computer. It is a powerful tool for debugging SoC systems.

The module definition is as follows:

```verilog
module uart2axi4 #(
    // clock frequency
    parameter  CLK_FREQ   = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE  = 115200,       // Unit : Hz
    parameter  PARITY     = "NONE",       // "NONE", "ODD", or "EVEN"
    // AXI4 config
    parameter  BYTE_WIDTH = 2,            // data width (bytes)
    parameter  A_WIDTH    = 32            // address width (bits)
) (
    input  wire                    rstn,
    input  wire                    clk,
    // AXI4 master ----------------------
    input  wire                    awready,  // AW
    output wire                    awvalid,
    output wire      [A_WIDTH-1:0] awaddr,
    output wire             [ 7:0] awlen,
    input  wire                    wready,   // W
    output wire                    wvalid,
    output wire                    wlast,
    output wire [8*BYTE_WIDTH-1:0] wdata,
    output wire                    bready,   // B
    input  wire                    bvalid,
    input  wire                    arready,  // AR
    output wire                    arvalid,
    output wire      [A_WIDTH-1:0] araddr,
    output wire             [ 7:0] arlen,
    output wire                    rready,   // R
    input  wire                    rvalid,
    input  wire                    rlast,
    input  wire [8*BYTE_WIDTH-1:0] rdata,
    // UART ----------------------
    input  wire                    i_uart_rx,
    output wire                    o_uart_tx
);
```

### 3.1 parameter 配置

- `CLK_FREQ` is the frequency of `clk` . User must correctly config it to get correnct baud rate.
- `BAUD_RATE` is UART baud rate.
- `PARITY` can be "NONE", "ODD", or "EVEN"
- `BYTE_WIDTH` is the byte-width of AXI4's data (`wdata` and `rdata`)
- `A_WIDTH` is the bit-width of AXI's address (`awaddr1` and `araddr`)

### 3.2 Clock and reset

`rstn` is low reset

`clk` is clock, all signals will be and should be changed at rise-edge of `clk`

### 3.3 UART signal

`o_uart_tx` is UART output signal.

`i_uart_rx` is UART input signal.

### 3.4 AXI4 master port

This module has an AXI4 master interface that can read and write AXI4 bus. We will not provide a detailed explanation of AXI4 timing here, please refer to https://www.xilinx.com/products/intellectual-property/axi.html

### 3.5 UART Command Format

To read and write to the AXI4 bus, a 'command-response' format is required:

- Command: The Host-PC sends commands to `uart2axi4` module through `i_uart_rx`;

- Execution: This module performs AXI4 read and write;

- Response: This module response message through `o_uart_tx` , it will be send to Host-PC.

Each command and response only contains printable ASCII characters and ends with carriage-return "\r", new-line "\n", or carriage return+new-line "\r\n".

#### Write Command

For AXI4 write operation, you should send command like:

```
w[address in hex] [write data 0 in hex] [write data 1 in hex] [write data 2 in hex] ... (end with "\n")
```

Write data must at least 1 and at most 256. These data will be written in one AXI4 burst.

For example:

```
w123 456 789 abc def 4321
```

means write address=0x0123, burst length=5, the 5 data are: 0x0456, 0x0789, 0x0abc, 0xdef, 0x4321.

For write command, the module will response "okay", "ok", or "o"

#### Read Command

For AXI4 read operation, you should send command like:

```
r[address in hex] [read burst length] (end with "\n")
```

The range of read burst length is 1-100 (note that hexadecimal values need to be sent, corresponding to decimal values of 1-256)

For example:

```
r123 a
```

means read address=0x123, burst length=0xa=10

for this command, the module may response:

```
0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
```

which means the ten read data are all 0x0000

#### Invalid Command

If the command format is undefined, the module will response "invalid", "inva", "in", or "i"

　

　


# 4. RTL Simulation

The simulation related files are all in the SIM folder.

### 4.1 Simulation for uart_tx and uart_rx

This simulation connect module `uart_tx` and module `uart_rx` , let `uart_tx` sending increase bytes via UART, and `uart_rx` will receive these bytes.

files:

- tb_axis_inc_source.v is an AXI-stream master to send increase bytes on AXI-stream, its AXI-stream will connect on `uart_tx` 's AXI-stream slave.
- tb_uart.v is simulation top.
- tb_uart_run_iverilog.bat is the command script to run iverilog command

Before using iverilog for simulation, you should install it, see [iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

Then double-click tb_uart_run_iverilog.bat to run simulation (on Windows), Then you can open dump.vcd to see the waveform.

### 4.2 Simulation for uart2axi4

This simulation sends a write command and a read command to uart2axi4.

files:

- tb_uart2axi4.v is simulation top.
- tb_uart2axi4_run_iverilog.bat is the command script to run iverilog command.

Before using iverilog for simulation, you should install it, see [iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

Then double-click tb_uart2axi4_run_iverilog.bat to run simulation (on Windows), Then you can open dump.vcd to see the waveform.

　

　

　

　

　


<span id="cn">Verilog-UART</span>
===========================

本库包含 3 个 Verilog 模块：

* **UART接收器**：[uart_rx.v](./RTL/uart_rx.v) , 具有一个 AXI-stream master 口，解析 UART 协议并将数据通过 AXI-stream 发送出去。
* **UART发送器**：[uart_tx.v](./RTL/uart_tx.v) , 具有一个 AXI-stream slave 口，接受 AXI-stream 数据并通过 UART 发送出去。
* **UART to AXI4 master**：[uart2axi4.v](./RTL/uart2axi4.v) , 它能接收上位机的 UART 命令，完成 AXI4 总线读写，并将结果反馈给上位机。是调试 SoC 系统的有力工具。

特点：

- 标准的 AXI 接口
- 可配置是否开启发送/接收 FIFO 以及 FIFO 的深度
- 可配置的 UART 波特率、校验位、停止位
- 分数分频：当时钟频率不能整除波特率时，各个 bit 的周期不一样，从而凑出一个更加接近的波特率。
- 波特率检查报告：仿真时会用 `$display` 打印波特率精确度。如果过于不精确则报错。

　

　

# 1. UART接收器 uart_rx

UART接收器的代码文件是 [uart_rx.v](./RTL/uart_rx.v) 。该模块没有子模块。

定义如下：

```verilog
module uart_rx #(
    // clock frequency
    parameter  CLK_FREQ  = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE = 115200,       // Unit : Hz
    parameter  PARITY    = "NONE",       // "NONE", "ODD", or "EVEN"
    // RX fifo depth
    parameter  FIFO_EA   = 0             // 0:no fifo   1,2:depth=4   3:depth=8   4:depth=16  ...  10:depth=1024   11:depth=2048  ...
) (
    input  wire        rstn,
    input  wire        clk,
    // UART RX input signal
    input  wire        i_uart_rx,
    // output AXI-stream master. Associated clock = clk. 
    input  wire        o_tready,
    output reg         o_tvalid,
    output reg  [ 7:0] o_tdata,
    // report whether there's a overflow
    output reg         o_overflow
);
```

### 1.1 parameter 配置

- `CLK_FREQ` 是时钟 `clk` 的频率，用户必须正确配置它，从而产生正确的波特率。
- `BAUD_RATE` 是 UART 波特率
- `PARITY` 决定了校验位，`"NONE"`是无校验位，`"ODD"`是奇校验位，`"EVEN"`是偶校验位。
- `FIFO_EA` 用来配置接收缓存：
  - `FIFO_EA=0` 代表无接收缓存，收到的字节必须立刻被用户处理，否则就会丢弃。
  - `FIFO_EA=1,2` 代表接收缓存大小=4；
  - `FIFO_EA=3` 代表接收缓存大小=8；
  - `FIFO_EA=4` 代表接收缓存大小=16；
  - ……

- 当 `FIFO_EA` 较大 (通常是>8)，FIFO 会用 BRAM 实现。

### 1.2 时钟和复位

`rstn` 是低电平复位。

`clk` 是时钟。所有信号的采样和改变都要在 `clk` 的上升沿进行。

### 1.3 UART 信号

`i_uart_rx` 是 UART 输入信号

### 1.4 AXI-stream master

`o_tready` , `o_tvalid` , `o_tdata`  构成了 AXI-stream master 接口

- `o_tvalid=1` 时，`o_tdata` 上会产生有效的接收到的字节，
- 如果用户能够接收当前字节，就让 `o_tready=1` 。
- 当 `o_tvalid` 和 `o_tready` 都是1时，握手成功，当前字节成功从模块的缓存中拿出。
- 当握手成功时，在下一周期：
  - 若缓存中还有收到的字节，则 `o_tvalid=1` ， `o_tdata` 上出现下一个收到的字节
  - 若缓存暂时空了，则 `o_tvalid=0`

>  :warning: 如果没有接收缓存（参数 `FIFO_EA=0` ），则模块不会等待用户是否能接受当前的字节，只要收到一个字节就让 `o_tvalid=1` 一个周期，并让该字节出现在 `o_tdata` 上。

### 1.5 溢出信号 `o_overflow` 

如果用户经常让 `o_tready=1` ，也即不及时拿走数据，则接受数据会在模块里的缓存里越攒越多，当缓存溢出时，新接收到的字节会被丢弃，并在 `o_overflow` 信号上产生一个周期的高电平脉冲。否则 `o_overflow` 一直保持 0 。

### 1.6 波特率检查

在仿真时，模块会根据用户的配置，打印各个 bit 的边沿的时间点以及其精确度。如果精度太差 (相对误差>8%) ，模块会使用 `$error` 系统调用报错，帮助用户提前发现配置错误。

例如，如果我们配置 `CLK_FREQ=5000000` (5MHz) ，`BAUD_RATE=115200` , `PARITY="ODD"`，则仿真会打印如下报告：

```
uart_rx :           parity = ODD
uart_rx :     clock period = 200 ns   (5000000    Hz)
uart_rx : baud rate period = 8681 ns   (115200     Hz)
uart_rx :      baud cycles = 43
uart_rx : baud cycles frac = 4
uart_rx :             __      ____ ____ ____ ____ ____ ____ ____ ____________
uart_rx :        wave   \____/____X____X____X____X____X____X____X____X____/
uart_rx :        bits   | S  | B0 | B1 | B2 | B3 | B4 | B5 | B6 | B7 | P   |
uart_rx : time_points  t0   t1   t2   t3   t4   t5   t6   t7   t8   t9   t10
uart_rx :
uart_rx : t1 - t0 = 8681 ns (ideal)  8600 +- 200 ns (actual).   error=281 ns   relative_error=3.232%
uart_rx : t2 - t0 = 17361 ns (ideal)  17400 +- 200 ns (actual).   error=239 ns   relative_error=2.752%
uart_rx : t3 - t0 = 26042 ns (ideal)  26000 +- 200 ns (actual).   error=242 ns   relative_error=2.784%
uart_rx : t4 - t0 = 34722 ns (ideal)  34800 +- 200 ns (actual).   error=278 ns   relative_error=3.200%
uart_rx : t5 - t0 = 43403 ns (ideal)  43400 +- 200 ns (actual).   error=203 ns   relative_error=2.336%
uart_rx : t6 - t0 = 52083 ns (ideal)  52000 +- 200 ns (actual).   error=283 ns   relative_error=3.264%
uart_rx : t7 - t0 = 60764 ns (ideal)  60800 +- 200 ns (actual).   error=236 ns   relative_error=2.720%
uart_rx : t8 - t0 = 69444 ns (ideal)  69400 +- 200 ns (actual).   error=244 ns   relative_error=2.816%
uart_rx : t9 - t0 = 78125 ns (ideal)  78200 +- 200 ns (actual).   error=275 ns   relative_error=3.168%
uart_rx : t10- t0 = 86806 ns (ideal)  86800 +- 200 ns (actual).   error=206 ns   relative_error=2.368%
```

　

　

# 2. UART发送器 uart_tx

UART发送器的代码文件是 [RTL/uart_tx.v](./RTL/uart_tx.v) 。该模块没有子模块。

该模块的定义如下：

```verilog
module uart_tx #(
    // clock frequency
    parameter  CLK_FREQ                  = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE                 = 115200,       // Unit : Hz
    parameter  PARITY                    = "NONE",       // "NONE", "ODD", or "EVEN"
    parameter  STOP_BITS                 = 2,            // can be 1, 2, 3, 4, ...
    // AXI stream data width
    parameter  BYTE_WIDTH                = 1,            // can be 1, 2, 3, 4, ...
    // TX fifo depth
    parameter  FIFO_EA                   = 0,            // 0:no fifo   1,2:depth=4   3:depth=8   4:depth=16  ...  10:depth=1024   11:depth=2048  ...
    // do you want to send extra byte after each AXI-stream transfer or packet?
    parameter  EXTRA_BYTE_AFTER_TRANSFER = "",           // specify a extra byte to send after each AXI-stream transfer. when ="", do not send this extra byte
    parameter  EXTRA_BYTE_AFTER_PACKET   = ""            // specify a extra byte to send after each AXI-stream packet  . when ="", do not send this extra byte
) (
    input  wire                    rstn,
    input  wire                    clk,
    // input  stream : AXI-stream slave. Associated clock = clk
    output wire                    i_tready,
    input  wire                    i_tvalid,
    input  wire [8*BYTE_WIDTH-1:0] i_tdata,
    input  wire [  BYTE_WIDTH-1:0] i_tkeep,
    input  wire                    i_tlast,
    // UART TX output signal
    output reg                     o_uart_tx
);
```

### 2.1 parameter 配置

- `CLK_FREQ` 是时钟 `clk` 的频率，用户必须正确配置它，从而产生正确的波特率。
- `BAUD_RATE` 是 UART 波特率
- `PARITY` 决定了校验位，`"NONE"`是无校验位，`"ODD"`是奇校验位，`"EVEN"`是偶校验位。
- `STOP_BITS` 是停止位数量，决定了模块会在发送完每字节后发送多少个停止位。
- `BYTE_WIDTH` 是 AXI-stream slave 接口的字节宽度 (也即 `i_tdata` 的字节数)
- `FIFO_EA` 用来配置发送缓存：
  - `FIFO_EA=0` 代表无发送缓存，AXI-stream 每握手成功一个数据，都必须等待发送完成，才能握手下一个数据
  - `FIFO_EA=1,2` 代表接收缓存大小=4；
  - `FIFO_EA=3` 代表接收缓存大小=8；
  - `FIFO_EA=4` 代表接收缓存大小=16；
  - ……
- 当 `FIFO_EA` 较大 (通常是>8)，FIFO 会用 BRAM 实现。
- `EXTRA_BYTE_AFTER_TRANSFER` 用来配置每次 AXI-stream transfer (也即握手成功一次) 时，是否要通过 UART 发送一个额外的字节
  - 如果不想发送额外的字节，就让 `EXTRA_BYTE_AFTER_TRANSFER=""`
  - 如果想发送额外的字节，比如空格字节 " "，就让 `EXTRA_BYTE_AFTER_TRANSFER=" "`

- `EXTRA_BYTE_AFTER_PACKET` 用来配置每次 AXI-stream packet (也即握手成功一次且 `tlast=1`) 时，是否要通过 UART 发送一个额外的字节
  - 如果不想发送额外的字节，就让 `EXTRA_BYTE_AFTER_PACKET=""`
  - 如果想发送额外的字节，比如回车字节 "\n"，就让 `EXTRA_BYTE_AFTER_PACKET="\n"`

### 2.2 时钟和复位

`rstn` 是低电平复位。

`clk` 是时钟。所有信号的采样和改变都要在 `clk` 的上升沿进行。

### 2.3 UART 信号

`o_uart_tx` 是 UART 输出信号

### 2.4 AXI-stream slave

`i_tready` , `i_tvalid` , `i_tdata` , `i_tkeep` , `i_tlast` 构成了 AXI-stream slave 接口：

- `i_tready=1` 代表模块内部缓存还有空间，可以接受数据。`i_tready=0` 代表模块内部缓存没空间了，无法接收数据。
- `i_tvalid=1` 代表用户想要发送一个数据到发送缓存里，同时 `i_tdata` , `i_tkeep` , `i_tlast` 需要有效。
- `i_tvalid` 和 `i_tready` 都是 1 时，握手成功，当前数据被成功存入缓存。
- `i_tdata` 的字节宽度通过参数 `BYTE_WIDTH` 来配置。
- `i_tdata` 遵循小端序，其低位字节先被发送，高位字节后被发送。
- `i_tkeep` 是字节有效信号：
  - `i_tkeep[0]=0` 代表 `i_tdata[7:0]` 这个字节有效，需要发送。否则不会发送；
  - `i_tkeep[1]=1` 代表 `i_tdata[15:8]` 这个字节有效，需要发送。否则不会发送；
  - `i_tkeep[2]=1` 代表 `i_tdata[23:16]` 这个字节有效，需要发送。否则不会发送；
  - ……
- `i_tlast` 是 AXI-stream 的 packet 分界信号。当发送一个数据时，如果 `i_tlast=1` ：
  - 如果 `EXTRA_BYTE_AFTER_PACKET` 指定了一个字节，UART 会额外发送这个字节；
  - 如果 `EXTRA_BYTE_AFTER_PACKET=""` ，不发送额外字节。换句话说，此时 `i_tlast` 无论是 0 还是 1 都没有任何影响。

### 2.5 波特率检查

在仿真时，模块会根据用户的配置，打印各个 bit 的边沿的时间点以及其精确度。如果精度太差 (相对误差>3%) ，模块会使用 `$error` 系统调用报错，帮助用户提前发现配置错误。

在前面 `uart_rx` 模块中已经对波特率检查举例，这里不再举例。

　

　


# 3. UART to AXI4 master (uart2axi4)

代码文件是 [RTL/uart2axi4.v](./RTL/uart2axi4.v) 。该模块会调用 [RTL/uart_tx.v](./RTL/uart_tx.v) 和  [RTL/uart_rx.v](./RTL/uart_rx.v) 。

该模块是一个 AXI4 master，它能接收上位机的 UART 命令，完成 AXI4 总线读写，并将结果反馈给上位机。是调试 SoC 系统的有力工具。

模块定义如下：

```verilog
module uart2axi4 #(
    // clock frequency
    parameter  CLK_FREQ   = 50000000,     // clk frequency, Unit : Hz
    // UART format
    parameter  BAUD_RATE  = 115200,       // Unit : Hz
    parameter  PARITY     = "NONE",       // "NONE", "ODD", or "EVEN"
    // AXI4 config
    parameter  BYTE_WIDTH = 2,            // data width (bytes)
    parameter  A_WIDTH    = 32            // address width (bits)
) (
    input  wire                    rstn,
    input  wire                    clk,
    // AXI4 master ----------------------
    input  wire                    awready,  // AW
    output wire                    awvalid,
    output wire      [A_WIDTH-1:0] awaddr,
    output wire             [ 7:0] awlen,
    input  wire                    wready,   // W
    output wire                    wvalid,
    output wire                    wlast,
    output wire [8*BYTE_WIDTH-1:0] wdata,
    output wire                    bready,   // B
    input  wire                    bvalid,
    input  wire                    arready,  // AR
    output wire                    arvalid,
    output wire      [A_WIDTH-1:0] araddr,
    output wire             [ 7:0] arlen,
    output wire                    rready,   // R
    input  wire                    rvalid,
    input  wire                    rlast,
    input  wire [8*BYTE_WIDTH-1:0] rdata,
    // UART ----------------------
    input  wire                    i_uart_rx,
    output wire                    o_uart_tx
);
```

### 3.1 parameter 配置

- `CLK_FREQ` 是时钟 `clk` 的频率，用户必须正确配置它，从而产生正确的波特率。
- `BAUD_RATE` 是 UART 波特率
- `PARITY` 决定了校验位，`"NONE"`是无校验位，`"ODD"`是奇校验位，`"EVEN"`是偶校验位。
- `BYTE_WIDTH` 是 AXI4 的宽度 (`wdata` 和 `rdata` 的字节宽度)
- `A_WIDTH` 是 AXI4 的地址宽度 (`awaddr` 和 `araddr` 的位宽)

### 3.2 时钟和复位

`rstn` 是低电平复位。

`clk` 是时钟。所有信号的采样和改变都要在 `clk` 的上升沿进行。

### 3.3 UART 信号

`o_uart_tx` 是 UART 输出信号 (连接上位机的 UART-RX)

`i_uart_rx` 是 UART 输入信号 (连接上位机的 UART-TX)

### 3.4 AXI4 master

该模块有一个 AXI4 master 接口，可读写 AXI4 总线。这里不对 AXI4 时序做详解，详见 https://www.xilinx.com/products/intellectual-property/axi.html

### 3.5 UART 命令格式

要读写 AXI4 总线，需要进行一次 "命令-响应" ：

- 命令：上位机通过 UART 发送命令给该模块的 `i_uart_rx` ；
- 执行：该模块执行 AXI4 读写；
- 响应：该模块通过 `o_uart_tx` 发送一个反馈信息给上位机的 UART 。

每个命令和响应都只包含可打印的 ASCII 字符，且以 回车 "\r" 、换行 "\n" 、或 回车+换行 "\r\n" 结尾。

#### 写命令

要进行 AXI4 写操作，格式如下：

```
w[地址的十六进制值] [写数据0的十六进制值] [写数据1的十六进制值] [写数据2的十六进制值] ... (注意命令要用"\n"结尾)
```

其中写数据最少1个，最多256个。这些数据会在一次 AXI4 burst 内写完。

例如：

```
w123 456 789 abc def 4321
```

代表写地址=0x0123，突发长度=5，写入的5个数据为 0x0456, 0x0789, 0x0abc, 0xdef, 0x4321 。

对于写命令，模块会响应 "okay" , "ok" , 或 "o"

### 读命令

要进行 AXI4 读操作，格式如下：

```
r[地址的十六进制值] [读突发长度] (注意命令要用"\n"结尾)
```

其中读突发长度的取值范围为 1~100 (注意需要发送十六进制值，对应的十进制值为1~256)

例如：

```
r123 a
```

代表读地址=0x123，突发长度=0xa=10。

对于读命令，模块会响应读到的数据 + "\n" ，各个数据之间用空格 " " 隔开。

例如，上述命令可能会响应：

```
0000 0000 0000 0000 0000 0000 0000 0000 0000 0000
```

代表读到的10个数据都是 0x0000

### 非法命令

如果命令格式错误，模块会响应 "invalid" , "inva" , “in" , 或者 "i"

　

　

# 4. 仿真

仿真相关的文件都在 SIM 文件夹中。

### 4.1 针对 uart_tx 和 uart_rx 模块的仿真

该仿真将 uart_tx 和 uart_rx 连起来，让 uart_tx 发送递增的字节，uart_rx 会解析出这些字节。

相关文件

- tb_axis_inc_source.v 是个 AXI-master ，产生递增的字节。它会连接到 uart_tx 的 AXI-slave 上。
- tb_uart.v 是仿真的顶层。
- tb_uart_run_iverilog.bat 包含了运行 iverilog 仿真的命令。

使用 iverilog 进行仿真前，需要安装 iverilog ，见：[iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

然后双击 tb_uart_run_iverilog.bat 运行仿真 (仅Windows)，然后可以打开生成的 dump.vcd 文件查看波形。

### 4.2 针对 uart2axi4 模块的仿真

该仿真发送一个写命令和一个读命令给 uart2axi4 。

相关文件

- tb_uart2axi4.v 是仿真的顶层。
- tb_uart2axi4_run_iverilog.bat 包含了运行 iverilog 仿真的命令。

使用 iverilog 进行仿真前，需要安装 iverilog ，见：[iverilog_usage](https://github.com/WangXuan95/WangXuan95/blob/main/iverilog_usage/iverilog_usage.md)

然后双击 tb_uart2axi4_run_iverilog.bat 运行仿真 (仅Windows)，然后可以打开生成的 dump.vcd 文件查看波形。

# Synthesizable RTL Architecture: Parameterized Synchronous FIFO

This directory contains the primary synthesizable SystemVerilog implementation of the `Parameterized_Synchronous_FIFO` core.

## 📁 File Manifest

| File | Language | Target Technology | Description |
|:---|:---:|:---:|:---|
| [`Parameterized_Synchronous_FIFO.sv`](Parameterized_Synchronous_FIFO.sv) | SystemVerilog (IEEE 1800) | ASIC / FPGA (Xilinx, Intel, Microchip) | Synthesizable parameterized synchronous FIFO with status flags |

---

## 📐 Parameter Definitions & Bit Sizing

```systemverilog
module Parameterized_Synchronous_FIFO
#(
    parameter FIFO_DEPTH   = 1024,  // Total word capacity of the FIFO
    parameter DATA_WIDTH   = 32,    // Width of data words (bits)
    parameter AF           = 10,    // Offset for almost_full flag: (FIFO_DEPTH - AF)
    parameter AE           = 10,    // Threshold for almost_empty flag: (<= AE)
    parameter AF_THRESHOLD = 1000,  // Upper watermark alert threshold
    parameter AE_THRESHOLD = 100    // Lower watermark alert threshold
)
```

### Pointer and Counter Bit-Sizing Mechanics

```systemverilog
localparam POINTER_SIZE = $clog2(FIFO_DEPTH);

reg [DATA_WIDTH   - 1 : 0] memory [FIFO_DEPTH - 1 : 0];
reg [POINTER_SIZE - 1 : 0] wr_ptr;
reg [POINTER_SIZE - 1 : 0] rd_ptr;
reg [POINTER_SIZE     : 0] data_counter;
```

* **Pointer Width (`POINTER_SIZE`):** Derived automatically via `$clog2(FIFO_DEPTH)`. For `FIFO_DEPTH = 1024`, `POINTER_SIZE = 10`, addressing locations `0` to `1023`.
* **Counter Width (`POINTER_SIZE + 1`):** A FIFO of depth $2^N$ can hold anywhere from $0$ up to $2^N$ elements (a total of $2^N + 1$ distinct states). Therefore, `data_counter` is declared with width `[POINTER_SIZE : 0]` (11 bits for depth 1024) to represent numbers from `0` up to `1024` without overflow.

---

## 🔌 Signal Interface Specifications

| Port Name | Direction | Width | Type | Active State | Description |
|:---|:---:|:---:|:---:|:---:|:---|
| `clk` | Input | 1-bit | `logic` | Rising Edge | Primary system clock governing all read and write transfers. |
| `rst_n` | Input | 1-bit | `logic` | Active-Low Async | Asynchronous reset. Initializes pointers, counters, and registers. |
| `wr_data` | Input | `DATA_WIDTH` | `logic` | Synchronous | Data payload to be pushed into memory. |
| `wr_en` | Input | 1-bit | `logic` | Active-High | Push/Enqueue command. Qualified by `!full`. |
| `full` | Output | 1-bit | `logic` | Active-High | Combinatorial indicator that FIFO has reached maximum capacity (`data_counter == FIFO_DEPTH`). |
| `almost_full` | Output | 1-bit | `logic` | Active-High | Asserts when free space is $\le \text{AF}$ (`data_counter >= FIFO_DEPTH - AF`). |
| `AF_threshold_alert` | Output | 1-bit | `logic` | Active-High | Early warning watermark alert (`data_counter >= AF_THRESHOLD`). |
| `rd_en` | Input | 1-bit | `logic` | Active-High | Pop/Dequeue command. Qualified by `!empty`. |
| `rd_data` | Output | `DATA_WIDTH` | `logic` | Registered | Data word read from memory at the current `rd_ptr`. |
| `empty` | Output | 1-bit | `logic` | Active-High | Combinatorial indicator that FIFO contains zero elements (`data_counter == 0`). |
| `almost_empty` | Output | 1-bit | `logic` | Active-High | Asserts when valid items $\le \text{AE}$ (`data_counter <= AE`). |
| `AE_threshold_alert` | Output | 1-bit | `logic` | Active-High | Low watermark alert (`data_counter <= AE_THRESHOLD`). |

---

## 🎛️ Detailed Architectural Operation

### 1. Status Flag Generation Equations

All status indicators are calculated combinatorially from `data_counter` to provide zero-latency immediate feedback to upstream and downstream controllers:

```systemverilog
assign empty              = (data_counter == 0)              ? 1'b1 : 1'b0;
assign almost_empty       = (data_counter <= AE)             ? 1'b1 : 1'b0;
assign AE_threshold_alert = (data_counter <= AE_THRESHOLD)    ? 1'b1 : 1'b0;

assign full               = (data_counter == FIFO_DEPTH)     ? 1'b1 : 1'b0;
assign almost_full        = (data_counter >= FIFO_DEPTH - AF)? 1'b1 : 1'b0;
assign AF_threshold_alert = (data_counter >= AF_THRESHOLD)   ? 1'b1 : 1'b0;
```

### 2. Write Operation & Overflow Protection

Writes are explicitly guarded by `wr_en && !full`. If a write is attempted when `full == 1`, memory write and pointer advancement are suppressed:

```systemverilog
if (wr_en && !full) begin
    memory[wr_ptr] <= wr_data;
    if (wr_ptr == FIFO_DEPTH - 1)
        wr_ptr <= 0;
    else
        wr_ptr <= wr_ptr + 1;
end
```

### 3. Read Operation & Underflow Protection

Reads are guarded by `rd_en && !empty`. If a read is attempted when `empty == 1`, the read pointer does not advance:

```systemverilog
if (rd_en && !empty) begin
    rd_data <= memory[rd_ptr];
    if (rd_ptr == FIFO_DEPTH - 1)
        rd_ptr <= 0;
    else
        rd_ptr <= rd_ptr + 1;
end
```

### 4. Simultaneous Read/Write Counter Tracking

When read and write occur concurrently, `data_counter` remains unchanged. The operational truth table is implemented as:

```systemverilog
case ({wr_en && !full, rd_en && !empty})
    2'b10: data_counter <= data_counter + 1; // Valid Write Only
    2'b01: data_counter <= data_counter - 1; // Valid Read Only
    default: data_counter <= data_counter;   // Both or Neither (No net change)
endcase
```

---

## ⚡ FPGA Synthesis & Memory Inference

When targeting modern FPGAs (AMD 7-Series, UltraScale, UltraScale+):

* **Depth $\ge 512$ words:** Vivado synthesis automatically infers **True Dual-Port Block RAM (RAMB36E1/E2 or RAMB18E1/E2)** for the `memory` array.
* **Depth $\le 64$ words:** Vivado automatically maps the array to **Distributed RAM (LUTRAM / SLICEM)** to conserve dedicated Block RAMs.
* **Timing & Critical Path:**
  * Combinatorial flags (`empty`, `full`) are computed from `data_counter` comparison.
  * For extreme timing closure at frequencies above 300 MHz on UltraScale+, the flags can optionally be registered or pipelined.

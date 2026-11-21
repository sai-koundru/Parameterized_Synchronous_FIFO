# Parameterized Synchronous FIFO with Multi-Tier Status Flags & Overflow/Underflow Protection

[![Language](https://img.shields.io/badge/Language-SystemVerilog%20%7C%20Verilog-green.svg)](#)
[![Target Hardware](https://img.shields.io/badge/Target-All%20FPGAs%20%26%20ASICs-orange.svg)](#)
[![Simulation Tool](https://img.shields.io/badge/Simulation-AMD%20Vivado%20%2F%20ModelSim%20%2F%20Questa-blue.svg)](#)
[![Design Type](https://img.shields.io/badge/Design-Synchronous%20FIFO%20Queue-purple.svg)](#)

A high-performance, fully synthesizable **Parameterized Synchronous First-In First-Out (FIFO) Memory Buffer** implemented in **SystemVerilog**. Designed as a foundational building block for digital signal processing (DSP) pipelines, high-throughput network packet buffering, DMA controllers, and on-chip interconnects (such as AXI4-Stream).

The module features a **comprehensive 6-flag status monitoring interface** (`full`, `almost_full`, `AF_threshold_alert`, `empty`, `almost_empty`, and `AE_threshold_alert`), hardware-level **overflow and underflow protection**, and full support for **concurrent single-cycle read and write operations**.

---

## 📌 Key Architectural Highlights

* **Fully Parameterized Geometry:**
  * Configurable depth (`FIFO_DEPTH`, defaults to 1024 words).
  * Configurable data width (`DATA_WIDTH`, defaults to 32 bits).
  * Automatically calculates optimal pointer bit-width using `localparam POINTER_SIZE = $clog2(FIFO_DEPTH)`.
* **Multi-Tier Status Flag Generation:**
  * **Full Hierarchy:** `full` (100% full), `almost_full` (programmable offset `FIFO_DEPTH - AF`), and `AF_threshold_alert` (custom upper watermark).
  * **Empty Hierarchy:** `empty` (0 items), `almost_empty` (programmable threshold `<= AE`), and `AE_threshold_alert` (custom lower watermark).
* **Hardware-Enforced Overflow & Underflow Protection:**
  * Write attempts when `full == 1` are safely discarded without pointer incrementation or memory corruption.
  * Read attempts when `empty == 1` are suppressed without pointer corruptions or invalid data counter underflow.
* **Concurrent Read & Write (Simultaneous Enqueue/Dequeue):**
  * Supports simultaneous single-cycle write and read operations.
  * The fill-level counter (`data_counter`) accurately tracks instantaneous occupancy across all operational permutations.
* **Memory Architecture Portability:**
  * Can infer either FPGA **Block RAM (BRAM)** or **Distributed RAM (LUTRAM)** depending on the configured depth and target synthesis constraints.

---

## 🎯 Practical FPGA & SoC Applications

| Application Domain | Practical Role |
|:---|:---|
| **DSP & Radar Pipelines** | Decoupling burst-mode processing blocks (e.g., FFT engines, matched filters, and decimators) from continuous data converters (ADCs/DACs). |
| **AXI4-Stream Interface Adapters** | Providing elastic buffering between master and slave streaming interfaces to absorb latency and backpressure (`tready`/`tvalid`). |
| **Flow Control & Watermarking** | Utilizing `almost_full` and `almost_empty` alerts to trigger upstream pause frames or downstream DMA interrupt requests before FIFO bounds are violated. |
| **Rate Matching & Elastic Buffers** | Absorbing bursty traffic spikes in Ethernet packet processing, PCIe transaction queues, and UART/SPI FIFO buffers. |

---

## 🏗️ Block Diagram & Interface Architecture

```text
                               +---------------------------------------------+
                               |        Parameterized_Synchronous_FIFO       |
                               |                                             |
            clk -------------->|> Clock                                      |
            rst_n ------------>|  Active-Low Asynchronous Reset              |
                               |                                             |
     [Write Interface]         |                                             |
     wr_data [DATA_WIDTH-1:0] >|==========> [ Dual-Port RAM ]                |
     wr_en ------------------->|            [  FIFO_DEPTH   ]                |
                               |                   |                         |
                               |                   v                         |
     full <--------------------|--- [ Status Flags Logic ]                   |
     almost_full <-------------|--- [   (data_counter)   ]                   |
     AF_threshold_alert <------|                                             |
                               |                                             |
                               |                                             |
     [Read Interface]          |                                             |
     rd_en ------------------->|-------------------------+                   |
                               |                         v                   |
     rd_data [DATA_WIDTH-1:0] <|========================= [ Output Reg ]     |
     empty <-------------------|--- [ Status Flags Logic ]                   |
     almost_empty <------------|--- [   (data_counter)   ]                   |
     AE_threshold_alert <------|                                             |
                               +---------------------------------------------+
```

---

## ⚙️ Module Parameters & Port Specifications

### Parameters

| Parameter | Type | Default Value | Description |
|:---|:---:|:---:|:---|
| `FIFO_DEPTH` | Integer | `1024` | Total storage capacity in data words. |
| `DATA_WIDTH` | Integer | `32` | Bit-width of each data word (`wr_data` and `rd_data`). |
| `AF` | Integer | `10` | Almost-full offset from top (`data_counter >= FIFO_DEPTH - AF`). |
| `AE` | Integer | `10` | Almost-empty threshold (`data_counter <= AE`). |
| `AF_THRESHOLD` | Integer | `1000` | Custom upper watermark threshold for early alert. |
| `AE_THRESHOLD` | Integer | `100` | Custom lower watermark threshold for early alert. |

### Port List

| Port Name | Direction | Width | Sensitivity | Description |
|:---|:---:|:---:|:---:|:---|
| `clk` | Input | 1-bit | Rising Edge | Master system clock. |
| `rst_n` | Input | 1-bit | Active-Low Async | Asynchronous active-low reset. Clears pointers, flags, and data registers. |
| `wr_data` | Input | `DATA_WIDTH` | Synchronous | Data word to be written into the FIFO. |
| `wr_en` | Input | 1-bit | Synchronous | Write enable request. Ignored if `full == 1`. |
| `full` | Output | 1-bit | Combinatorial | Asserted when `data_counter == FIFO_DEPTH`. |
| `almost_full` | Output | 1-bit | Combinatorial | Asserted when remaining slots $\le \text{AF}$. |
| `AF_threshold_alert` | Output | 1-bit | Combinatorial | Asserted when occupancy $\ge \text{AF\_THRESHOLD}$. |
| `rd_en` | Input | 1-bit | Synchronous | Read enable request. Ignored if `empty == 1`. |
| `rd_data` | Output | `DATA_WIDTH` | Registered | Data word retrieved from the current read pointer location. |
| `empty` | Output | 1-bit | Combinatorial | Asserted when `data_counter == 0`. |
| `almost_empty` | Output | 1-bit | Combinatorial | Asserted when occupancy $\le \text{AE}$. |
| `AE_threshold_alert` | Output | 1-bit | Combinatorial | Asserted when occupancy $\le \text{AE\_THRESHOLD}$. |

---

## 🔬 Verification & Simulation Highlights

Behavioral simulation was performed using **AMD Vivado Simulator (xsim)** at 100 MHz ($T_{\text{clk}} = 10\text{ ns}$) covering edge cases, flag transitions, overflow/underflow, and simultaneous operations.

### Key Verified Behaviors:

1. **Clean Reset & Initialization (`Reset_state.png`):**
   * Upon `rst_n` deassertion, `empty`, `almost_empty`, and `AE_threshold_alert` assert immediately.
   * `data_counter`, `wr_ptr`, and `rd_ptr` are cleared to `0`.
2. **Gradual Fill & Multi-Tier Full Progression (`full_signals.png`):**
   * At item 1000: `AF_threshold_alert` asserts.
   * At item 1014: `almost_full` asserts ($1024 - 10 = 1014$).
   * At item 1024: `full` asserts; write pointer wraps cleanly back to 0.
3. **Write-Overflow Immunity (`write_overflow.png`):**
   * With the FIFO 100% full, the testbench forced continuous writes up to 4000 items.
   * `data_counter` remained clamped at 1024, `wr_ptr` did not advance, and memory remained uncorrupted.
4. **Read-Underflow Immunity (`read_overflow.png`):**
   * After completely draining the FIFO, 2000 continuous read strobes were applied.
   * `data_counter` remained clamped at 0, preventing negative counter rollover.
5. **Simultaneous Read & Write Streaming (`continuous_write_n_read.png`):**
   * Tested simultaneous `wr_en = 1` and `rd_en = 1`.
   * Pointers incremented synchronously, maintaining a steady occupancy of 10 items without data loss.

*(For full high-resolution waveform walkthroughs and detailed analysis, refer to [`02_RESULTS/README.md`](02_RESULTS/README.md)).*

---

## 📂 Repository Structure

```text
Parameterized_Synchronous_FIFO/
├── README.md                      # Project overview and specifications (this file)
├── .gitignore                     # Git ignore rules for AMD Vivado and EDA simulators
├── LICENSE                        # MIT Open-Source License
│
├── 00_RTL/                        # Synthesizable RTL source files
│   ├── Parameterized_Synchronous_FIFO.sv  # Primary SystemVerilog FIFO core
│   └── README.md                  # Comprehensive RTL architecture and synthesis notes
│
├── 01_TESTBENCH/                  # Verification testbench environment
│   ├── tb_Parameterized_Synchronous_FIFO.v# Self-testing Verilog simulation testbench
│   └── README.md                  # Verification test plan and simulation guide
│
└── 02_RESULTS/                    # Simulation waveforms from Vivado Simulator
    ├── Reset_state.png            # Reset behavior and initial flag states
    ├── empty_signals.png          # Empty flag deassertion progression during write
    ├── full_signals.png           # Multi-tier full flag assertion progression
    ├── read_operation.png         # Sequential read drain and data integrity verification
    ├── write_overflow.png         # Hardware write-overflow protection test
    ├── read_overflow.png          # Hardware read-underflow protection test
    ├── continuous_write_n_read.png# Simultaneous concurrent write & read operation
    └── README.md                  # Complete waveform walkthrough and test matrix
```

---

## 💻 Instantiation Template

```systemverilog
// Example: 512-word, 16-bit wide synchronous FIFO with customized thresholds
Parameterized_Synchronous_FIFO #(
    .FIFO_DEPTH   (512),
    .DATA_WIDTH   (16),
    .AF           (8),     // almost_full asserts at 504 items
    .AE           (8),     // almost_empty asserts at <= 8 items
    .AF_THRESHOLD (480),   // early full alert at 480 items
    .AE_THRESHOLD (32)     // early empty alert at 32 items
) u_fifo_512x16 (
    .clk                (sys_clk),
    .rst_n              (sys_rst_n),
    
    // Write interface
    .wr_data            (stream_data_in),
    .wr_en              (stream_valid_in),
    .full               (stream_fifo_full),
    .almost_full        (stream_almost_full),
    .AF_threshold_alert (stream_af_alert),
    
    // Read interface
    .rd_en              (stream_read_req),
    .rd_data            (stream_data_out),
    .empty              (stream_fifo_empty),
    .almost_empty       (stream_almost_empty),
    .AE_threshold_alert (stream_ae_alert)
);
```

---

## ⚙️ How to Build and Simulate

### In AMD Vivado (v2020.1 to v2024.x)
1. Create a new RTL Project targeting any AMD FPGA/MPSoC device (Artix-7, Kintex-7, Zynq, UltraScale+).
2. Add `00_RTL/Parameterized_Synchronous_FIFO.sv` as a **Design Source**.
3. Add `01_TESTBENCH/tb_Parameterized_Synchronous_FIFO.v` as a **Simulation Source**.
4. In Flow Navigator, click **Run Simulation $\rightarrow$ Run Behavioral Simulation**.
5. Set simulation run time to `100 us` (`run 100us;`).

### Batch / Tcl Execution
```tcl
launch_simulation -mode behavioral
run 100 us
```

---

## 👤 Author

**K Sree Sai Venkat**  
FPGA & RTL Design Engineer  
Specialization: Digital Signal Processing (DSP) & High-Speed FPGA Architectures  

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

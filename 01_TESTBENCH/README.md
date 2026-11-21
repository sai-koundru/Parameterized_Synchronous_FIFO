# Verification Environment & Testbench: Parameterized Synchronous FIFO

This directory contains the behavioral simulation testbench for the `Parameterized_Synchronous_FIFO` module, implemented in Verilog for AMD Vivado Simulator (`xsim`).

## 📁 File Manifest

| File | Language | Purpose |
|:---|:---:|:---|
| [`tb_Parameterized_Synchronous_FIFO.v`](tb_Parameterized_Synchronous_FIFO.v) | Verilog (IEEE 1364) | State-machine driven behavioral testbench covering all FIFO corner cases |

---

## 🎯 Verification Strategy & Methodology

The testbench employs an FSM-controlled stimulus generator operating on the **negative edge of the clock (`negedge clk`)**. This is a recognized industry best practice in RTL verification that guarantees ample setup and hold times for the synchronous FIFO operating on `posedge clk`.

### Verification Test Plan & States

```
                +--------------------+
                |       RESET        |
                | rst_n = 0 for 100ns|
                +---------+----------+
                          |
                          v
                +--------------------+
                | 1. FULL_WRITE      |  Writes 1024 words (1 to 1024).
                | (Fill to Capacity) |  Asserts AF_threshold_alert, almost_full, and full.
                +---------+----------+
                          |
                          v
                +--------------------+
                | 2. FULL_READ       |  Reads 1024 words sequentially.
                | (Drain to Empty)   |  Verifies FIFO ordering and asserts AE alerts and empty.
                +---------+----------+
                          |
                          v
                +--------------------+
                | 3. OVERFLOW_WRITE  |  Attempts to write up to 4000 items into full FIFO.
                | (Overflow Protect) |  Verifies memory and counters are protected.
                +---------+----------+
                          |
                          v
                +--------------------+
                | 4. OVERFLOW_READ   |  Attempts 2000 reads on an empty FIFO.
                | (Underflow Protect)|  Verifies data_counter stays 0 and rd_ptr is protected.
                +---------+----------+
                          |
                          v
                +--------------------+
                | 5. SIM_READ_WRITE  |  Simultaneous wr_en = 1 and rd_en = 1.
                | (Concurrent R/W)   |  Verifies constant occupancy tracking (data_counter = 10).
                +--------------------+
```

---

## 🔍 Test Phase Deep Dive

### Phase 1: `FULL_WRITE` (Fill to Maximum Capacity)
* **Stimulus:** Increments `wr_data` from `1` up to `1024` with `wr_en = 1`.
* **Checks:**
  * At count 1000: `AF_threshold_alert` asserts.
  * At count 1014 ($1024 - 10$): `almost_full` asserts.
  * At count 1024: `full` asserts.
  * Transition to `FULL_READ` upon reaching count 1024.

### Phase 2: `FULL_READ` (Drain Completely to Empty)
* **Stimulus:** Asserts `rd_en = 1` for 1024 consecutive clock cycles.
* **Checks:**
  * Verifies FIFO ordering: `rd_data` sequence matches `1, 2, 3, ..., 1024` with 1-cycle read latency.
  * At occupancy 100: `AE_threshold_alert` asserts.
  * At occupancy 10: `almost_empty` asserts.
  * At occupancy 0: `empty` asserts.

### Phase 3: `OVERFLOW_WRITE` (Hardware Overflow Protection)
* **Stimulus:** With the FIFO completely full, continues asserting `wr_en = 1` while incrementing `wr_data` up to `4000`.
* **Checks:**
  * `full` remains `1`.
  * `data_counter` remains fixed at `1024`.
  * `wr_ptr` does not advance past `0`, preventing circular overwrite of unread data.

### Phase 4: `OVERFLOW_READ` (Hardware Underflow Protection)
* **Stimulus:** Drains the FIFO and continues pulsing `rd_en = 1` for 2000 cycles.
* **Checks:**
  * `empty` remains `1`.
  * `data_counter` does not decrement below `0` (no negative underflow or roll-over).
  * `rd_ptr` does not advance past `0`.

### Phase 5: `SIM_READ_WRITE` (Simultaneous Concurrent Transfers)
* **Stimulus:** Writes 10 words into the FIFO, then asserts **both** `wr_en = 1` and `rd_en = 1` simultaneously.
* **Checks:**
  * Pointers `wr_ptr` and `rd_ptr` advance in lockstep.
  * Occupancy stays fixed at `data_counter = 10`.
  * Streamed data emerges on `rd_data` after an exact 10-cycle FIFO pipeline latency without missing a single byte.

---

## 🚀 Running Behavioral Simulation in AMD Vivado

### GUI Method
1. Launch **Vivado** and open the project.
2. In the **Sources** pane, expand **Simulation Sources $\rightarrow$ sim_1**.
3. Right-click `tb_Parameterized_Synchronous_FIFO` and choose **Set as Top**.
4. In Flow Navigator, click **Run Simulation $\rightarrow$ Run Behavioral Simulation**.
5. Set signal radixes:
   * `data_counter`, `wr_data`, `rd_data`, `wr_ptr`, `rd_ptr` $\rightarrow$ **Unsigned Decimal**.
6. Run the simulation for at least **100 us** (`run 100us;`).

### Vivado Tcl One-Liner
```tcl
launch_simulation -mode behavioral
run 100 us
```

Refer to [`02_RESULTS/README.md`](../02_RESULTS/README.md) for full screenshots and detailed waveform timing analysis.

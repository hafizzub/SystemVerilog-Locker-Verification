# 🛠️ SystemVerilog Register Controller Design & Verification Suite

This repository showcases the implementation and verification of a **Digital Register Controller (`reg_ctrl`)** in SystemVerilog, developed as part of advanced digital verification practice inspired by ChipVerify.

The testbench successfully transitions from basic manual stimulus to a **fully automated, OOP-based constrained-random checking environment** utilizing a modular verification architecture.

---

## 📸 System Architecture

This diagram illustrates how the Verification Architecture monitors, injects, and validates the hardware (modeled through a Bank & Auditing Metaphor):

![Bank and QC Testbench](https://raw.githubusercontent.com/google/interactive-media-ads-ios-interactive-samples/main/images/bank_and_testbench_metaphor.png)

- **Design Under Test (DUT - `reg_ctrl`)**: A storage room managing 256 memory locations (drawers) with standard handshake-driven delay timing during read operations.
- **Verification Suite (`tb`)**: An automated Quality Control (QC) loop checking validation integrity over consecutive clock cycles.

---

## 🧱 Design Summary (`design.sv`)

The `reg_ctrl` module operates synchronously on the clock's rising edge (`posedge clk`) to handle the following operations:
- **Asynchronous/Synchronous Reset**: Clears the 256-word array data memory (`ctrl`) to a default boot status of `16'h1234` when active-low reset is asserted (`rstn == 0`).
- **Data Write (Deposits)**: When selected (`sel == 1`), available (`ready == 1`), and write is enabled (`wr == 1`), incoming input `wdata` is written directly into the specified address `addr`.
- **Data Read (Withdrawals)**: When selected (`sel == 1`), available (`ready == 1`), and read is enabled (`wr == 0`), the stored value from `ctrl[addr]` is put onto the `rdata` bus. 
- **Wait-State Latency (`ready` handshaking)**: To emulate real-world hardware latency, read requests deassert the `ready` signal (`ready == 0`) for exactly one clock cycle, signaling the testbench to wait until the operation completes.

---

## 🚨 Verification Suite Summary (`testbench.sv`)

This testbench utilizes a highly structured Object-Oriented Programming (OOP) environment:
1. **Transaction Object (`reg_item`)**: A basic data container representing a single bus access, with randomizable (`rand`) fields for Address, Data, and Access Type.
2. **Generator (`generator`)**: Automatically generates randomized transactions based on constraints and pushes them to the driver while waiting for the execution handshake `@(drv_done)`.
3. **Driver (`driver`)**: Receives transaction objects from the generator's mailbox, drives the physical signals on the virtual interface, and actively respects the `ready` busy-state.
4. **Monitor (`monitor`)**: An independent, passive observer that snoops the bus interface, reconstructs the bus transactions (handling the 1-cycle read latency), and routes them to the scoreboard.
5. **Scoreboard (`scoreboard`)**: Actively validates the design by mimicking the storage in an internal associative/index array (`refq[256]`). It compares DUT read responses against expected values to detect mismatches.
6. **Environment (`env_w_gen`)**: A container class that instantiates, wires (via mailboxes and event handles), and runs all verification components in parallel.

---

## ⚡ Simulation Run Trace (Example Log Analysis)

Detailed timeline analysis based on simulator execution:
- **T=20ns**: Reset is released (`_if.rstn <= 1`), transitioning the system to operational state. Both Driver and Monitor start.
- **T=30ns**: The Generator creates a randomized transaction. The Driver fetches it and applies a Write command to address `0xbe` with data value `0xbc7a`.
- **T=50ns**: The Monitor detects the transaction and forwards it to the Scoreboard. The Scoreboard registers that `0xbc7a` has been saved into `0xbe`.
- **T=110ns**: A randomized Read command is driven to address `0x57`.
- **T=130ns**: Read transaction detected by the DUT, prompting the deassertion of the `ready` signal (`ready == 0`). The Driver actively stalls and waits.
- **T=150ns**: The busy cycle completes. The Monitor observes `rdata` output as `0x1234` (the post-reset default value). The Scoreboard verifies the validity of the read. Result: **PASS!**

---

### 🚀 Try It on EDA Playground

You can directly run, modify, and analyze waveforms for this complete design and testbench on [EDA Playground](https://www.edaplayground.com/) using standard simulation tools like **Aldec Riviera-PRO** or **Cadence Xcelium**.

# FPGA-Based Programmable Logic Controller (PLC)

> **EEE 304 — Digital Electronics Laboratory | July 2025**  
> Bangladesh University of Engineering and Technology (BUET)  
> Department of Electrical and Electronic Engineering  
> Section: B1 | Group: 05

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Architecture](#system-architecture)
- [Hardware Requirements](#hardware-requirements)
- [Repository Structure](#repository-structure)
- [Getting Started](#getting-started)
- [Operating Modes](#operating-modes)
- [Edit Mode — Page Reference](#edit-mode--page-reference)
- [Instruction Set Reference](#instruction-set-reference)
- [Example Programs](#example-programs)
- [Implementation Results](#implementation-results)
- [Known Limitations](#known-limitations)
- [Future Work](#future-work)
- [Team](#team)
- [References](#references)
- [License](#license)

---

## Overview

This project implements a **soft Programmable Logic Controller (PLC)** on an FPGA development board, capable of executing user-defined ladder-logic programs entered directly through on-board switches and pushbuttons — without any external PC or programming software.

The controller is implemented in **Verilog HDL** and targets the **Digilent Nexys A7-100T** (Artix-7 FPGA). It supports the standard industrial scan-cycle execution model: inputs are sampled, ladder rungs are evaluated top-to-bottom, and outputs are updated synchronously each clock cycle.

A demo video of the working prototype is available here:  
📺 **[YouTube Demo](https://youtu.be/V50mvGif0Us?si=VbsnC_AaJEPqV7VM)**

---

## Features

| Category | Details |
|---|---|
| **Ladder Capacity** | 8 rungs × 3 parallel lanes × 7 cells per lane |
| **Inputs** | 20 (SW0–SW14 + 5 pushbuttons) |
| **Outputs** | 16 (Q0–Q15) |
| **Markers** | 16 (M0–M15) |
| **Timers** | 8× TON (on-delay) + 8× TOF (off-delay) |
| **Counters** | 8× CTU (up-counter) with RESC (reset) |
| **Contact Types** | Normally-Open (NO), Normally-Closed (NC), Wire, Empty |
| **Source Classes** | I, Q, M, TON.DN, TOF.DN, C.DN |
| **Actions** | COIL, SET, RST (for Q and M), TON, TOF, CTU, RESC |
| **Programming Interface** | On-board, page-based edit mode (no PC required) |
| **Display** | 8-digit 7-segment display with mode-dependent formatting |

---

## System Architecture

```
Physical Inputs (SW, BTN, RESET)
         |
         v
 Debounce + One-Pulse Front-End
         |
         v
  Edit/Run Mode Controller
  |                       |
  v                       v
Edit Page Decoder    Ladder Scan Engine <------ Program Memory
                          |
                          v
              Q / M / Timer / Counter Registers
                          |
                          v
              LED and Seven-Segment Driver
```

### HDL Modules

| Module | Description |
|---|---|
| `plc_multi_rung_top.v` | Top-level controller: ladder storage, scan engine, UI logic |
| `debounce_onepulse.v` | Synchronous debounce filter with single-pulse output for pushbuttons |
| `tick_gen.v` | Derives 1 ms timer tick and display refresh tick from 100 MHz clock |
| `sevenseg_driver.v` | Time-division multiplexed 8-digit 7-segment display driver |

### Architectural Parameters

```verilog
localparam integer MAX_RUNGS   = 8;
localparam integer LANES       = 3;
localparam integer LOGIC_COLS  = 7;
localparam integer N_INPUTS    = 20;
localparam integer N_OUTPUTS   = 16;
localparam integer N_MARKERS   = 16;
localparam integer N_TIMERS    = 8;
localparam integer N_COUNTERS  = 8;
```

---

## Hardware Requirements

- **FPGA Board:** Digilent Nexys A7-100T (Artix-7 XC7A100T)
- **EDA Tool:** AMD Vivado Design Suite (2020.x or later recommended)
- **Clock:** 100 MHz onboard oscillator (CLK100MHZ)
- **No external components required**

---

## Repository Structure

```
├── src/
│   ├── plc_multi_rung_top.v        # Top-level PLC module
│   ├── debounce_onepulse.v         # Button debounce and one-pulse generator
│   ├── tick_gen.v                  # 1 ms and display refresh tick generator
│   └── sevenseg_driver.v           # 7-segment display driver
├── constraints/
│   └── plc_multi_rung_top_xdc.xdc  # Nexys A7 pin constraint file
├── sim/
│   └── (testbench files)
├── docs/
│   └── EEE304-Jul2025-B1-G05.pdf   # Full project report
└── README.md
```

---

## Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/fpga-plc.git
cd fpga-plc
```

### 2. Open in Vivado

1. Launch **Vivado** and create a new RTL project.
2. Add all `.v` files from `src/` as design sources.
3. Add `constraints/plc_multi_rung_top_xdc.xdc` as a constraint file.
4. Set the target part to `xc7a100tcsg324-1` (Nexys A7-100T).

### 3. Synthesize and Implement

Run **Synthesis → Implementation → Generate Bitstream** from the Vivado Flow Navigator.

### 4. Program the Board

Connect the Nexys A7 via USB, open the **Hardware Manager**, and program the device with the generated `.bit` file.

### 5. Power-On Behavior

After programming, the board loads a default ladder:
- **Rung 0:** `[NO I0] [NO I1] --> (COIL Q0)`
- Toggle SW0 and SW1 to verify Q0 responds correctly.

---

## Operating Modes

Mode is selected by **SW15**:

| SW15 | Mode | Display Prefix | Description |
|---|---|---|---|
| `0` | **Edit Mode** | `E` | Program ladder logic using page-based interface |
| `1` | **Run Mode** | `A` | Execute ladder and observe results in real time |

### Run Mode — I/O Mapping

| Signal | PLC Input | Notes |
|---|---|---|
| SW0–SW14 | I0–I14 | Direct physical inputs |
| BTNL | I15 | Debounced |
| BTNR | I16 | Debounced |
| BTNU | I17 | Debounced |
| BTND | I18 | Debounced |
| BTNC | I19 | Debounced |
| SW15 | — | Reserved for mode selection |

### Run Mode — Display Format

```
A | active_rungs_m1 | rung_true[3:0] | rung_true[7:4] | rung_vis[3:0] | rung_vis[7:4] | Q[3:0] | M[3:0]
```

### Run Mode — LED Mapping

| LEDs | Meaning |
|---|---|
| LED[7:0] | Rung-visible results (may show timer/counter done bits, not raw Q) |
| LED[15:8] | Physical inputs I0–I7 |

---

## Edit Mode — Page Reference

Navigate pages using **BTNL** (previous) / **BTNR** (next).  
**Best Practice:** Turn all switches OFF before entering a new page, then set only the required bits.

### Page 0 — Coordinate Selection

| Switch Field | Meaning |
|---|---|
| SW[2:0] | Column (0–6) |
| SW[4:3] | Lane (0–2) |
| SW[7:5] | Rung (0–7) |

- **BTNC:** Load selected coordinate
- **BTNU / BTND:** Increment / decrement column

### Page 1 — Cell Programming

| Switch Field | Meaning |
|---|---|
| SW[1:0] | Cell type: `0`=EMPTY, `1`=WIRE, `2`=NO, `3`=NC |
| SW[4:2] | Source class: `0`=NONE, `1`=I, `2`=Q, `3`=M, `4`=TON.DN, `5`=TOF.DN, `6`=C.DN |
| SW[9:5] | Source index |

- **BTNC:** Write cell | **BTND:** Delete cell

### Page 2 — Action Programming

| SW[3:0] | Action | SW[7:4] | Action Index |
|---|---|---|---|
| `0` | NONE | — | — |
| `1` | COIL Q | Output index | Q0–Q15 |
| `2` | SET Q | Output index | — |
| `3` | RST Q | Output index | — |
| `4` | COIL M | Marker index | M0–M15 |
| `5` | SET M | Marker index | — |
| `6` | RST M | Marker index | — |
| `7` | TON | Timer index | T0–T7 |
| `8` | TOF | Timer index | T0–T7 |
| `9` | CTU | Counter index | C0–C7 |
| `10` | RESC | Counter index | — |

- **BTNC:** Write rung action

### Page 3 — Preset Low Byte

- SW[7:0] → bits [7:0] of 16-bit preset (used for TON, TOF, CTU)
- **BTNC:** Commit

### Page 4 — Preset High Byte

- SW[7:0] → bits [15:8] of 16-bit preset
- **BTNC:** Commit

### Page 5 — Service & Validation

| Switch | Function |
|---|---|
| SW[2:0] | `active_rungs_m1` (number of active rungs **minus 1**) |
| SW3 | Load built-in demo program |
| SW4 | Clear entire program memory |
| SW5 | Clear runtime state only (Q, M, timers, counters) |
| SW6 | Clear current rung only |

- **BTNC:** Execute selected service action
- **Error codes:** `01` = active rung has no cells | `02` = active rung has no action
- **LED13:** Program valid | **LED14:** Program dirty | **LED15:** Error present

---

## Instruction Set Reference

### Cell Types

| Code | Symbol | Description |
|---|---|---|
| `0` | EMPTY | Cell not used |
| `1` | WIRE | Passes power unconditionally |
| `2` | NO | Normally-Open contact — true when source = 1 |
| `3` | NC | Normally-Closed contact — true when source = 0 |

### Lane and Rung Evaluation

- **Series (within a lane):** Logical AND of all non-empty cells
- **Parallel (across lanes):** Logical OR of all non-empty lanes

### Timer Behavior

| Timer | Behavior |
|---|---|
| **TON** | Done bit asserts after rung is true for preset duration (ms). Clears when rung goes false. |
| **TOF** | Done bit asserts immediately when rung is true. Stays high for preset duration after rung goes false. |

### Counter Behavior

| Instruction | Behavior |
|---|---|
| **CTU** | Increments accumulator on each rising edge of rung truth. Done bit asserts when count ≥ preset. |
| **RESC** | Clears accumulator and done bit of the specified counter when rung is true. |

---

## Example Programs

### Small — Single NO Contact

```
Rung 0:  [ I0 ] ──────────────── ( Q0 )
```
Q0 follows I0 directly.

### Medium — Parallel Branches with Marker Latch

```
Rung 0:  [ I0 ][ I1 ] ─────────── ( SET M0 )
          [ I2 ][/I3 ] ─┘

Rung 1:  [ I7 ] ───────────────── ( RST M0 )
```
M0 latches when either branch is true; resets when I7 is asserted.

### Large — Four-Rung Integrated Demonstration

```
Rung 0:  [ I0 ][ I1 ] ─────────── ( SET M0 )
          [ I2 ][/I3 ] ─┘

Rung 1:  [ M0 ][ I4 ] ─────────── ( TON T0, 1000 ms )

Rung 2:  [ T0.DN ][ I5 ] ──────── ( COIL Q0 )
          [ T0.DN ][ I6 ] ─┘

Rung 3:  [ I7 ] ───────────────── ( RST M0 )
```

---

## Implementation Results

| Metric | Value |
|---|---|
| Target Device | Nexys A7-100T (XC7A100T) |
| Slice LUTs Used | 13,577 (21.41%) |
| Slice Registers Used | 2,894 (2.28%) |
| Estimated On-Chip Power | 0.170 W |
| Worst Negative Setup Slack | −46.578 ns |
| Timing Closure at 100 MHz | ❌ Not achieved (functional prototype) |

> **Note:** The design is functionally correct for educational demonstration purposes. Timing closure at the full 100 MHz system clock requires further combinational path optimization or pipelining of the scan engine.

---

## Known Limitations

- **Volatile program storage:** The ladder program is lost on reset or power cycle.
- **Timing not closed:** The current implementation does not meet 100 MHz timing constraints and should be treated as a functional demonstrator, not a production design.
- **No isolated I/O:** The design cannot be connected directly to industrial field signals.
- **Page-based UI:** Switch reuse across edit pages requires careful procedure; unintended writes are possible if switches are not cleared between pages.

---

## Future Work

- **Nonvolatile storage** via external Flash/EEPROM for program retention across power cycles
- **Improved UI** via serial terminal, VGA display output, or USB keyboard support
- **Industrial I/O** with opto-isolated inputs and relay/transistor outputs
- **Expanded instruction set:** comparators, arithmetic blocks, retentive timers
- **Communication support:** UART diagnostics, Modbus, Ethernet connectivity
- **Architecture optimization:** pipelining the scan engine to achieve timing closure

---

## Team

| Student ID | Name |
|---|---|
| 2106078 | Tahmid Mahmud Fahim |
| 2106080 | Abid Uz Zaman |
| 2106083 | Robayet Hossen Bapon |
| 2106084 | Md. Rakibul Islam |
| 2106085 | Afrina Rahman |

**Course Instructors:**  
- Sadman Sakib Ahbab, Assistant Professor, Department of EEE, BUET  
- Archishman Sarkar, Part-Time Lecturer, Department of EEE, BUET

---

## References

1. IEC 61131-3:2025 — *Programmable Controllers – Part 3: Programming Languages*, IEC, 2025.
2. F. D. Petruzella, *Programmable Logic Controllers*, 5th ed. McGraw-Hill, 2016.
3. W. Bolton, *Programmable Logic Controllers*, 6th ed. Newnes/Elsevier, 2015.
4. H. Zhu et al., "Research on FPGA-based programmable logic controllers' technology," *TELKOMNIKA*, vol. 11, no. 12, 2013.
5. N. W. Bergmann, "FPGA implementations of ladder diagrams," *Modern Applied Science*, vol. 7, no. 3, 2013.
6. Digilent, [Nexys A7 Reference Manual](https://digilent.com/reference/programmable-logic/nexys-a7/reference-manual).
7. AMD, *Vivado Design Suite User Guide: Synthesis (UG901)*.
8. AMD, *7 Series FPGAs Clocking Resources User Guide (UG472)*.

---

## License

This project was developed as an academic laboratory assignment at BUET and is intended for educational use only. It is not certified for industrial deployment. Please refer to your institution's academic policies regarding reuse and distribution.

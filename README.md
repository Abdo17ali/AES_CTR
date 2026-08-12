# End-to-End AES-128 CTR Cryptographic Processor — FPGA & ASIC

[![Language](https://img.shields.io/badge/HDL-Verilog-blue.svg)](#rtl-design)
[![FPGA](https://img.shields.io/badge/FPGA-AMD%20Kria%20KV260-orange.svg)](#fpga-implementation)
[![ASIC](https://img.shields.io/badge/ASIC-SKY130%20130nm-green.svg)](#asic-implementation)
[![Verification](https://img.shields.io/badge/Verification-UVM-purple.svg)](#verification--simulation)
[![Status](https://img.shields.io/badge/Status-Completed-success.svg)](#results-summary)
[![License](https://img.shields.io/badge/License-Not%20Specified-lightgrey.svg)](#license)

> **End-to-End Design, Verification, and Hardware Implementation of an AES Cryptographic Processor Across FPGA and ASIC Platforms**

A high-throughput, deeply pipelined **AES-128 CTR-mode cryptographic processor** developed at RTL, functionally verified using **UVM**, prototyped on the **AMD Kria KV260 FPGA**, and physically implemented using an open-source **SkyWater 130 nm ASIC flow**.

The project combines cryptographic hardware design, high-throughput pipelining, hardware security monitoring, FPGA hardware/software co-design, and ASIC physical implementation into a complete end-to-end digital IC design flow.

---

## Table of Contents

* [Overview](#overview)

  * [What is AES-CTR?](#what-is-aes-ctr)
  * [What Does This Project Do?](#what-does-this-project-do)
  * [Why is Hardware AES-CTR Important?](#why-is-hardware-aes-ctr-important)
* [Architecture & Block Diagram](#architecture--block-diagram)

  * [Overall Architecture](#overall-architecture)
  * [CTR Processing Flow](#ctr-processing-flow)
  * [High-Throughput Pipeline](#high-throughput-pipeline)
  * [FPGA System Architecture](#fpga-system-architecture)
* [Features](#features)
* [Project Structure](#project-structure)
* [RTL Design Details](#rtl-design-details)

  * [AES-128 Core](#aes-128-core)
  * [Pipeline Architecture](#pipeline-architecture)
  * [S-Box Architecture](#s-box-architecture)
  * [Key Expansion](#key-expansion)
  * [CTR Mode](#ctr-mode)
  * [Security Monitor](#security-monitor)
  * [AXI Interface](#axi-interface)
* [Verification & Simulation](#verification--simulation)

  * [UVM Verification Architecture](#uvm-verification-architecture)
  * [Verification Strategy](#verification-strategy)
  * [Test Cases](#test-cases)
  * [Verification Results](#verification-results)
* [FPGA Implementation](#fpga-implementation)

  * [Target Platform](#target-platform)
  * [Hardware/Software Co-Design](#hardwaresoftware-co-design)
  * [Resource Utilization](#resource-utilization)
  * [Timing Results](#timing-results)
  * [Performance Results](#performance-results)
* [ASIC Implementation](#asic-implementation)

  * [Technology](#technology)
  * [ASIC Flow](#asic-flow)
  * [Physical Implementation Results](#physical-implementation-results)
* [Tools Used](#tools-used)
* [How To Run](#how-to-run)

  * [Simulation](#simulation)
  * [FPGA Implementation](#fpga-implementation-steps)
  * [ASIC Flow](#asic-flow-steps)
* [Results Summary](#results-summary)
* [References](#references)
* [Author & Contact](#author--contact)
* [License](#license)

---

# Overview

## What is AES-CTR?

**AES-CTR (Counter Mode)** is a block-cipher mode in which AES is used to encrypt a sequence of counter values rather than directly encrypting the plaintext.

For each block:

```text
Keystream_i = AES_K(Counter_i)

Ciphertext_i = Plaintext_i XOR Keystream_i
```

Decryption uses the same operation:

```text
Plaintext_i = Ciphertext_i XOR AES_K(Counter_i)
```

The counter is incremented for every processed block.

This gives CTR mode stream-cipher-like behavior while retaining AES as the underlying cryptographic primitive.

---

## What Does This Project Do?

This project implements a **high-throughput pipelined AES-128 CTR cryptographic processor** and takes the design through multiple stages of the digital IC development flow:

```text
Cryptographic Specification
          │
          ▼
      RTL Design
          │
          ▼
     UVM Verification
          │
          ▼
     FPGA Prototyping
          │
          ▼
 Hardware/Software Co-Design
          │
          ▼
   ASIC Synthesis & P&R
          │
          ▼
 SKY130 Physical Implementation
```

The project evolved from a pipelined AES-128 encryption core into a complete CTR-mode cryptographic processor.

The presentation also documents an **AES-128 ECB core** as the foundation for the subsequent CTR implementation. The ECB implementation was used to investigate pipeline architecture, S-Box optimization, key expansion, and FPGA performance before extending the architecture to CTR mode.

---

## Why is Hardware AES-CTR Important?

Hardware implementation provides several advantages for cryptographic acceleration:

* High throughput
* Deterministic latency
* Hardware acceleration
* Efficient FPGA implementation
* Potential ASIC deployment
* Dedicated security monitoring
* Hardware/software co-design
* Reduced dependency on software-only cryptographic processing

The project specifically targets high-throughput applications where cryptographic processing can become a system bottleneck.

---

# Architecture & Block Diagram

## Overall Architecture

The main AES-CTR architecture consists of five major functional blocks:

```text
                         ┌───────────────────────┐
                         │      Input Data       │
                         │   Plaintext / Data    │
                         └───────────┬───────────┘
                                     │
                                     ▼
                         ┌───────────────────────┐
                         │ Counter Block         │
                         │ Generator             │
                         │                       │
                         │ IV + Counter          │
                         │ Auto Increment        │
                         └───────────┬───────────┘
                                     │
                                     ▼
                  ┌─────────────────────────────────────┐
                  │          AES-128 Pipeline            │
                  │                                     │
                  │ Stage 1 → Stage 2 → ... → Stage 5 │
                  │                                     │
                  │ Dual-Round Implementation           │
                  └───────────┬─────────────────────────┘
                              │
                              │ AES(Counter)
                              ▼
                    ┌─────────────────────┐
                    │     Delay Line      │
                    │                     │
                    │ Align plaintext /   │
                    │ data with keystream │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │      XOR Unit       │
                    │                     │
                    │ Data XOR Keystream  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Output Ciphertext │
                    └─────────────────────┘

                         ┌─────────────────────┐
                         │   Security Monitor  │
                         │                     │
                         │ Nonce Reuse         │
                         │ Counter Overflow    │
                         │ Counter Exhaustion  │
                         │ Reset Attack        │
                         └─────────────────────┘
```

---

## CTR Processing Flow

The CTR datapath follows the sequence documented in the project presentation:

```text
IV loaded once
     │
     ▼
Counter increments automatically
     │
     ▼
AES encrypts counter
     │
     ▼
AES keystream generated
     │
     ▼
Keystream aligned through delay line
     │
     ▼
Plaintext XOR Keystream
     │
     ▼
Ciphertext
```

The same AES encryption core is used for encryption and decryption because CTR mode relies on XORing the data with the generated keystream.

---

## High-Throughput Pipeline

The AES engine uses a **five-stage pipeline** with a dual-round implementation.

Key architectural characteristics:

| Parameter            |                      Design |
| -------------------- | --------------------------: |
| Pipeline depth       |                    5 stages |
| AES pipeline latency |              8 clock cycles |
| Blocks processed     |       1 block / clock cycle |
| Round implementation |                  Dual-round |
| Key expansion        |              Pre-calculated |
| CTR operation        | Automatic counter increment |

The architecture is designed to maintain continuous pipeline utilization and maximize throughput.

---

# Features

## Cryptographic Features

* AES-128 encryption core
* AES-128 CTR mode
* Stream-cipher-like operation
* Encryption and decryption using the same AES datapath
* Automatic counter increment
* IV-based counter initialization
* NIST/FIPS test-vector verification

## High-Performance Architecture

* Five-stage AES pipeline
* Dual-round implementation
* One block per clock cycle
* Eight-cycle pipeline latency
* Pre-calculated round keys
* Optimized S-Box implementation
* Parameterized LUT/GF S-Box architecture

## Security Monitoring

The CTR implementation includes hardware-level security monitoring for:

* Nonce reuse detection
* Counter overflow detection
* Counter exhaustion warning
* Reset attack detection
* Error classification
* Critical-error handling
* Warning-error recovery through `error_clear`

## FPGA Features

* AMD Kria KV260 target
* ARM + FPGA SoC architecture
* AXI Lite control interface
* AXI Stream data interface
* DMA-based data movement
* FIFO buffering
* Endian conversion
* Linux/PetaLinux software control
* Custom Vivado IP packaging

## Verification Features

* UVM-based verification environment
* Self-checking scoreboard
* Golden AES reference model
* NIST SP 800-38A test vectors
* Constrained-random verification
* Security-oriented test cases
* Error recovery testing
* Pipeline latency verification
* Functional coverage tracking

## ASIC Features

* SkyWater 130 nm technology
* Open-source physical implementation flow
* Multi-corner timing analysis
* DRC verification
* LVS verification
* IR-drop analysis
* Final physical layout
* Zero unrouted nets

---

# Project Structure

The presentation does not specify the exact GitHub repository directory names. Therefore, the following is a **recommended repository organization** reflecting the design stages documented in the project.

```text
AES-CTR-Cryptographic-Processor/
│
├── README.md
├── LICENSE
│
├── rtl/
│   ├── aes/
│   │   ├── aes_core.v
│   │   ├── aes_round.v
│   │   ├── sub_bytes.v
│   │   ├── shift_rows.v
│   │   ├── mix_columns.v
│   │   ├── add_round_key.v
│   │   └── key_expansion.v
│   │
│   ├── ctr/
│   │   ├── ctr_counter.v
│   │   ├── ctr_datapath.v
│   │   ├── delay_line.v
│   │   └── xor_unit.v
│   │
│   ├── security/
│   │   ├── nonce_reuse_detector.v
│   │   ├── counter_exhaustion.v
│   │   ├── counter_overflow.v
│   │   └── security_monitor.v
│   │
│   └── interfaces/
│       ├── axi_lite_wrapper.v
│       └── axi_stream_interface.v
│
├── tb/
│   ├── uvm/
│   │   ├── agent/
│   │   ├── driver/
│   │   ├── monitor/
│   │   ├── scoreboard/
│   │   ├── sequences/
│   │   └── tests/
│   │
│   └── reference_model/
│
├── fpga/
│   ├── vivado/
│   ├── constraints/
│   ├── ip/
│   ├── dma/
│   └── software/
│
├── asic/
│   ├── synthesis/
│   ├── floorplan/
│   ├── placement/
│   ├── routing/
│   ├── timing/
│   └── physical_verification/
│
├── docs/
│   ├── architecture/
│   ├── verification/
│   ├── fpga/
│   └── asic/
│
└── results/
    ├── simulation/
    ├── fpga/
    └── asic/
```

> **Note:** This is a logical repository structure rather than a claim about the exact directory names in the original project files.

---

# RTL Design Details

## AES-128 Core

The AES datapath implements the standard AES transformation sequence:

```text
SubBytes
    │
    ▼
ShiftRows
    │
    ▼
MixColumns
    │
    ▼
AddRoundKey
```

The project uses an optimized pipelined architecture to increase throughput.

### AES transformations

| Transformation | Hardware Implementation                      |
| -------------- | -------------------------------------------- |
| SubBytes       | Optimized S-Box                              |
| ShiftRows      | Hard-wired byte permutation                  |
| MixColumns     | GF(2⁸) matrix multiplication using XOR trees |
| AddRoundKey    | Bitwise XOR                                  |
| Key Expansion  | Pre-calculated round keys                    |

---

## Pipeline Architecture

The project compares a conventional sequential AES architecture with the proposed pipelined implementation.

| Conventional AES         | Proposed Architecture     |
| ------------------------ | ------------------------- |
| Sequential               | 5-stage pipeline          |
| Lower throughput         | Higher throughput         |
| Basic architecture       | Optimized architecture    |
| Single-round progression | Dual-round implementation |

The pipeline is designed so that multiple blocks can be simultaneously present in different stages.

The presentation reports:

* **Five pipeline stages**
* **One block every clock cycle**
* **Eight-cycle latency for the CTR pipeline**
* **Dual-round implementation**

---

## S-Box Architecture

Two S-Box implementation approaches were investigated:

1. LUT-based implementation
2. GF arithmetic implementation

### Standalone S-Box comparison

| Metric       |  LUT-Based | GF Arithmetic |
| ------------ | ---------: | ------------: |
| LUTs         |      8,412 |        12,477 |
| Frequency    | 232.56 MHz |    166.67 MHz |
| Clock period |    4.30 ns |       6.00 ns |
| Power        |     1.00 W |        3.17 W |

The LUT-based implementation provides higher frequency and throughput with fewer LUT resources in the reported standalone comparison.

The RTL architecture also supports selecting between LUT and GF arithmetic through a synthesis parameter.

---

## Key Expansion

The project uses **pre-calculated round keys** for high-throughput operation.

The presentation compares:

| Feature              | On-the-Fly        | Pre-calculated    |
| -------------------- | ----------------- | ----------------- |
| Key generation       | During encryption | Before encryption |
| Encryption latency   | Higher            | Lower             |
| Throughput           | Lower             | Higher            |
| Hardware complexity  | Lower             | Higher            |
| Register usage       | Lower             | Higher            |
| Pipeline suitability | Limited           | Excellent         |

The design specifically uses pre-calculated keys to keep the five-stage pipeline fully utilized.

The presentation also documents:

* Support for AES-128
* AES-192
* AES-256
* Two round keys per clock
* Pre-calculated key expansion

---

# CTR Mode Architecture

The CTR implementation extends the AES encryption core with a counter-generation and data-combination datapath.

```text
              IV
              │
              ▼
       ┌───────────────┐
       │ Counter       │
       │ Generator     │
       └───────┬───────┘
               │
               ▼
       ┌───────────────┐
       │ AES Pipeline  │
       └───────┬───────┘
               │
               ▼
        AES Keystream
               │
               ▼
       ┌───────────────┐
Data ─►│ XOR           │──► Output
       └───────────────┘
```

The IV is loaded once for an active session, after which the counter is automatically incremented for each block.

---

# Security Monitor

The CTR engine includes dedicated hardware security monitoring.

## Nonce Reuse Detection

The verification plan checks that:

* The IV is accepted only once per active session.
* Attempting to load a different IV while locked triggers `ERR_NONCE_REUSE`.

This is particularly important for CTR mode because reuse of a nonce/counter sequence with the same key can expose relationships between plaintexts.

## Counter Exhaustion

The design generates a warning when the counter reaches the documented threshold:

```text
0xFFFFF000
```

## Counter Overflow

The counter reaches its maximum value at:

```text
0xFFFFFFFF
```

Overflow triggers a critical halt condition.

## Error Handling

The design distinguishes between warning-level and critical errors:

```text
Warning Error
     │
     ├── error_clear
     │
     └── Recovery

Critical Error
     │
     └── Full Reset Required
```

---

# AXI Interface

The FPGA implementation wraps the AES accelerator using an **AXI Lite interface** for software control.

The presentation identifies the following FPGA system interfaces:

* AXI Lite Control
* AXI Stream Data
* DMA Transfer
* Linux Application

The AXI wrapper:

* Converts the standalone RTL into reusable IP.
* Provides memory-mapped software control.
* Enables communication with the Zynq-based processing system.
* Simplifies integration through Vivado IP Integrator.
* Allows the AES accelerator to be reused in future FPGA projects.

---

# Verification & Simulation

## UVM Verification Architecture

The project uses **Universal Verification Methodology (UVM)** for scalable and reusable verification.

The verification environment contains the following conceptual components:

```text
                 ┌─────────────────────┐
                 │       UVM Test      │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │     Sequences       │
                 └──────────┬──────────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │       Driver        │
                 └──────────┬──────────┘
                            │
                            ▼
                       ┌─────────┐
                       │   DUT   │
                       └────┬────┘
                            │
                            ▼
                 ┌─────────────────────┐
                 │      Monitor        │
                 └──────────┬──────────┘
                            │
                 ┌──────────▼──────────┐
                 │     Scoreboard      │
                 │                     │
                 │ Golden AES Model    │
                 └─────────────────────┘
```

The environment uses:

* Driver
* Monitor
* Scoreboard
* Golden AES reference model
* Functional coverage
* Constrained-random sequences
* Self-checking verification

---

## Verification Strategy

The verification plan covers both functional correctness and security properties.

### Functional Verification

The design verifies that:

* AES encryption matches NIST SP 800-38A F.5.1 vectors.
* AES decryption matches NIST SP 800-38A F.5.2 vectors.
* Encryption/decryption round-trip restores plaintext.
* Key loading works correctly.
* `keys_ready` timing is correct.
* IV loading is correctly controlled.
* Counter increments correctly.
* Pipeline latency remains constant.

### Security Verification

The verification environment checks:

* Nonce reuse detection.
* Counter exhaustion warning.
* Counter overflow handling.
* Critical error recovery.
* Keystream uniqueness across counters.
* Key avalanche behavior.
* IV avalanche behavior.
* Plaintext bit propagation.
* Absence of X/Z values on critical outputs.
* Correct error-code generation.

---

## Test Cases

The presentation specifies the following verification objectives:

| Test                   | Expected Behavior                   |
| ---------------------- | ----------------------------------- |
| NIST encryption vector | Matches F.5.1                       |
| NIST decryption vector | Matches F.5.2                       |
| Encrypt → decrypt      | Original plaintext recovered        |
| Back-to-back blocks    | No output drops                     |
| Blocked input          | No output stream leakage            |
| `error_clear`          | Warning errors recover              |
| Critical errors        | Full reset required                 |
| Keystream uniqueness   | No repeated keystream blocks        |
| Key bit flip           | Approximately 50% output-bit change |
| IV bit flip            | Approximately 50% output-bit change |
| Plaintext bit flip     | Exactly one output-bit change       |
| X/Z checking           | No unknown critical outputs         |
| IV reuse               | `ERR_NONCE_REUSE`                   |
| Counter exhaustion     | Warning at `0xFFFFF000`             |
| Counter overflow       | Critical halt at `0xFFFFFFFF`       |
| Pipeline latency       | Constant 8 cycles                   |

---

## Verification Results

The FPGA/system execution results reported in the presentation show:

| Metric                  |            Baremetal / JTAG | Linux / PetaLinux |
| ----------------------- | --------------------------: | ----------------: |
| Correctness             |                  5/5 PASSED |        5/5 PASSED |
| Single-block latency    | 490 ns (49 cycles @ 99 MHz) |            530 ns |
| Throughput, 1000 blocks |                     13 Mbps |       100.29 Mbps |
| Blocks/sec              |                     103,412 |           783,479 |
| Bitstream load time     |                         N/A |            133 ms |

---

# FPGA Implementation

## Target Platform

The design was prototyped on the:

**AMD Kria KV260**

The KV260 is used as an ARM + FPGA SoC platform, enabling hardware/software co-design.

The FPGA prototype was intended to:

* Validate RTL on real hardware.
* Identify timing and integration problems.
* Validate high-speed data transfer.
* Verify system interfaces.
* Enable Linux-based control.
* Reduce risk before ASIC physical implementation.

---

## Hardware/Software Co-Design

The implemented FPGA system combines:

```text
             Linux Application
                    │
                    ▼
              AXI Control
                    │
                    ▼
        ┌───────────────────────┐
        │      FPGA PL          │
        │                       │
        │ AES-CTR Accelerator   │
        │ AXI Interface         │
        │ FIFO                  │
        │ DMA                   │
        └───────────────────────┘
                    ▲
                    │
                AXI Stream
```

The presentation identifies:

* Custom AXI wrapper
* Three DMA engines
* Endian conversion
* FIFO buffer
* Python/Linux control software

---

# FPGA Resource Utilization

For the hardware/software co-design implementation:

| FPGA Resource   | Utilized | Available | Utilization |
| --------------- | -------: | --------: | ----------: |
| CLB LUTs        |   13,546 |   117,120 |      11.57% |
| CLB Registers   |    8,782 |   234,240 |       3.75% |
| Block RAM Tiles |       12 |       144 |       8.33% |
| DSP Slices      |        0 |     1,248 |       0.00% |
| BUFGCE          |        1 |       112 |       0.89% |

No DSP slices are required by the implementation reported in the presentation.

---

# FPGA Timing Results

## Post-Implementation System Timing

| Parameter             |              Result |
| --------------------- | ------------------: |
| Implemented frequency |             100 MHz |
| Clock period          |           10.000 ns |
| WNS                   |           +3.362 ns |
| WHS                   |           +0.011 ns |
| TNS                   |                0 ns |
| Setup violations      |                   0 |
| Hold violations       |                   0 |
| Timing status         | All constraints met |

---

## Standalone Core Performance

The presentation reports:

| Parameter                       |          Result |
| ------------------------------- | --------------: |
| Hardware platform frequency     |         100 MHz |
| Standalone core frequency       |         250 MHz |
| Minimum standalone clock period |            4 ns |
| Pipeline depth                  |        5 stages |
| Encryption latency              |  5 clock cycles |
| Key expansion latency           | 44 clock cycles |
| Encryption latency @ 100 MHz    |           50 ns |
| Standalone throughput           |         32 Gbps |

---

# CTR FPGA Performance

The CTR implementation was evaluated at several development stages:

| Development Stage           |  Frequency | Throughput | Throughput |
| --------------------------- | ---------: | ---------: | ---------: |
| OOC Core                    | 297.40 MHz | 38.07 Gbps | 4,759 MB/s |
| Post-Synthesis Wrapper      | 240.85 MHz | 30.83 Gbps | 3,853 MB/s |
| Post-Implementation P&R     | 179.86 MHz | 23.02 Gbps | 2,877 MB/s |
| Active Operational Standard |    100 MHz | 12.80 Gbps | 1,600 MB/s |

The post-implementation result represents the practical performance after physical implementation, while the 100 MHz configuration represents the active operational standard reported for the system.

---

# ASIC Implementation

## Technology

The ASIC implementation targets:

**SkyWater 130 nm (SKY130)**

The presentation uses an open-source physical implementation flow.

---

# ASIC Flow

The documented ASIC flow includes:

```text
RTL
 │
 ▼
Synthesis
 │
 ▼
Floorplanning
 │
 ▼
Placement
 │
 ▼
Clock / Timing Optimization
 │
 ▼
Routing
 │
 ▼
Physical Verification
 │
 ├── DRC
 ├── LVS
 └── IR Drop
 │
 ▼
Final Layout
```

---

# ASIC Tools

The presentation identifies the following open-source tools/technologies:

* OpenROAD
* LiberLane
* SkyWater 130 nm PDK
* Magic VLSI
* Netgen
* KLayout

---

# ASIC Physical Implementation Results

## Timing

| Metric                           |   Result |
| -------------------------------- | -------: |
| Setup WNS — worst corner         | +2.20 ns |
| Hold WNS — worst corner          | +0.30 ns |
| Timing violations                |        0 |
| PVT corners passed               |        9 |
| Maximum frequency — worst corner | 43.9 MHz |
| Maximum frequency — typical      | 86.4 MHz |

---

## Area

| Metric           |          Result |
| ---------------- | --------------: |
| Die size         | 1897 × 1908 µm² |
| Total die area   |      ≈ 3.62 mm² |
| Standard cells   |         147,966 |
| Sequential cells |           4,739 |
| Core utilization |           30.8% |

---

## Power

| Power Component |        Result |
| --------------- | ------------: |
| Internal power  |      77.85 mW |
| Switching power |     125.69 mW |
| Leakage power   |     0.0036 mW |
| **Total power** | **203.54 mW** |

---

## Routing

| Routing Metric   |  Result |
| ---------------- | ------: |
| Total wirelength |  6.13 m |
| Total vias       | 819,443 |
| Unrouted nets    |       0 |

---

## Physical Verification

| Verification            | Result  |
| ----------------------- | ------- |
| DRC                     | Clean   |
| LVS                     | Clean   |
| IR drop                 | 3.42 mV |
| IR drop relative to VDD | 0.19%   |

---

## ASIC Throughput

| Condition  | Throughput |
| ---------- | ---------: |
| Worst case |  5.62 Gbps |
| Typical    | 11.06 Gbps |

---

# Tools Used

| Tool / Technology   | Role                                              |
| ------------------- | ------------------------------------------------- |
| Verilog RTL         | Hardware description                              |
| UVM                 | Functional verification                           |
| AMD Vivado          | FPGA synthesis, implementation and IP integration |
| AMD Kria KV260      | FPGA/SoC prototype                                |
| PetaLinux           | Linux FPGA software environment                   |
| AXI                 | Hardware/software communication                   |
| DMA                 | High-speed data transfer                          |
| OpenROAD            | ASIC physical implementation                      |
| LiberLane           | ASIC flow                                         |
| SkyWater 130 nm PDK | ASIC technology                                   |
| Magic VLSI          | Physical verification/layout                      |
| Netgen              | LVS                                               |
| KLayout             | Layout inspection/verification                    |

---

# How To Run

> **Important:** The presentation documents the architecture, tools, implementation flow, and measured results, but it does not provide the exact filenames, Makefiles, TCL scripts, simulator commands, or repository-specific build scripts. The commands below therefore describe the required flow rather than claiming exact project commands.

## Simulation

### 1. Compile the RTL

Compile the AES-CTR RTL together with the verification environment and required packages.

A typical simulator flow is:

```bash
# Example flow — adapt paths to the repository structure
<simulator> -compile <rtl_sources> <uvm_sources>
```

### 2. Run the UVM testbench

```bash
<simulator> -run <test_name>
```

### 3. Verify the results

The verification environment should check:

```text
NIST AES-CTR vectors
        │
        ├── Encryption
        ├── Decryption
        ├── Round-trip
        ├── Counter operation
        ├── Nonce reuse
        ├── Counter exhaustion
        ├── Counter overflow
        └── Pipeline latency
```

---

# FPGA Implementation Steps

The documented FPGA flow is:

```text
RTL
 │
 ▼
Vivado Project
 │
 ▼
Synthesis
 │
 ▼
Implementation
 │
 ▼
Timing Analysis
 │
 ▼
Bitstream Generation
 │
 ▼
KV260
 │
 ▼
Linux / PetaLinux
 │
 ▼
Application
```

Recommended execution sequence:

```bash
# Create/open the Vivado project
vivado

# Synthesize the design
# Run Synthesis from Vivado

# Run implementation
# Run Implementation from Vivado

# Generate the bitstream
# Generate Bitstream from Vivado
```

The exact Tcl/project commands depend on the repository scripts and are not specified in the presentation.

---

# ASIC Flow Steps

The ASIC flow follows the documented open-source physical implementation process:

```text
RTL
 │
 ▼
Synthesis
 │
 ▼
OpenROAD
 │
 ▼
Floorplan
 │
 ▼
Placement
 │
 ▼
Clock Tree
 │
 ▼
Routing
 │
 ▼
Timing Analysis
 │
 ▼
DRC / LVS / IR Drop
 │
 ▼
Final Layout
```

Typical flow stages:

```bash
# RTL synthesis
<asic-synthesis-flow>

# Physical implementation
<openroad-flow>

# DRC
<magic-or-drc-flow>

# LVS
<netgen-flow>

# Layout inspection
<klayout-flow>
```

The exact scripts and command-line options should be taken from the repository's ASIC flow directory once the implementation scripts are included.

---

# Results Summary

## FPGA vs ASIC

| Metric                     |                                          FPGA / KV260 |          ASIC / SKY130 |
| -------------------------- | ----------------------------------------------------: | ---------------------: |
| Technology                 |                                        AMD Kria KV260 |        SkyWater 130 nm |
| Main operating frequency   |                                               100 MHz |    43.9 MHz worst case |
| Maximum reported frequency |                                        297.40 MHz OOC |       86.4 MHz typical |
| Throughput                 |                                  12.80 Gbps @ 100 MHz |   5.62 Gbps worst case |
| Typical throughput         |                                                     — |             11.06 Gbps |
| Pipeline                   |                                              5 stages |   5-stage architecture |
| CTR latency                |                                              8 cycles |                      — |
| Total power                | 1.000 W for reported LUT-based standalone comparison* |              203.54 mW |
| Area                       |                                        FPGA resources |             ≈ 3.62 mm² |
| LUTs                       |                          13,546 system implementation |                    N/A |
| Registers                  |                           8,782 system implementation | 4,739 sequential cells |
| BRAM                       |                                              12 tiles |                    N/A |
| DSP                        |                                                     0 |                    N/A |
| Timing violations          |                                                     0 |                      0 |
| Physical verification      |                         FPGA implementation completed |  DRC clean / LVS clean |
| Unrouted nets              |                                                     — |                      0 |

*The **1.000 W** FPGA value belongs to the presentation's standalone LUT-based vs. GF S-Box comparison and should not be interpreted as the complete hardware/software co-design power figure.

---

# Key Achievements

The project demonstrates an end-to-end cryptographic hardware implementation covering:

```text
                AES Cryptography
                       │
                       ▼
                RTL Architecture
                       │
                       ▼
              Pipeline Optimization
                       │
                       ▼
                UVM Verification
                       │
                       ▼
               FPGA Prototyping
                       │
                       ▼
            Hardware/Software Co-Design
                       │
                       ▼
              ASIC Physical Design
                       │
                       ▼
             SKY130 Final Layout
```

### Reported highlights

* Five-stage pipelined AES architecture.
* Dual-round implementation.
* One-block-per-cycle pipeline architecture.
* Eight-cycle CTR pipeline latency.
* Pre-calculated key expansion.
* Parameterized LUT/GF S-Box implementation.
* Hardware nonce-reuse monitoring.
* Counter exhaustion and overflow protection.
* UVM self-checking verification environment.
* NIST/FIPS test-vector verification.
* AMD Kria KV260 FPGA prototype.
* AXI-based hardware/software integration.
* DMA-based FPGA data movement.
* Linux/PetaLinux software control.
* 297.40 MHz OOC FPGA frequency.
* 23.02 Gbps post-implementation FPGA throughput.
* 12.80 Gbps active 100 MHz operational throughput.
* SkyWater 130 nm ASIC implementation.
* 0 timing violations across 9 PVT corners.
* DRC clean.
* LVS clean.
* 0 unrouted nets.
* ≈3.62 mm² reported ASIC die area.
* 203.54 mW reported ASIC total power.
* 5.62 Gbps worst-case ASIC throughput.

---

# References

1. National Institute of Standards and Technology (NIST), **“Advanced Encryption Standard (AES),” FIPS 197**.

2. National Institute of Standards and Technology (NIST), **“Recommendation for Block Cipher Modes of Operation: Methods and Techniques,” SP 800-38A**.

3. SkyWater Technology, **SkyWater 130 nm Process Design Kit (SKY130)**.

4. AMD, **Kria KV260 Vision AI Starter Kit** — FPGA/SoC prototyping platform used for the hardware implementation.

5. Universal Verification Methodology (UVM) — methodology used for the project's functional verification environment.

---

# Author & Contact

## Digital IC Design Team — Obour Engineering

**Presented by:**

* Abanoub Sabry Abdel Sayed
* Abdulrahman Mohamed Hamad
* Ramadan Mohamed Sokkar
* Omar Atef Abdul-Ghaffar
* Farah Ahmed Bedear
* Abdulrahman Ali Nasr

**Supervisor:**

**Assoc. Prof. Saad El-Sayed**

---

## Project Scope

This project was developed as an end-to-end digital IC design effort covering:

```text
Digital IC Design
       +
Cryptographic Hardware
       +
RTL Development
       +
UVM Verification
       +
FPGA Prototyping
       +
Hardware/Software Co-Design
       +
ASIC Physical Implementation
```

The objective is to demonstrate the complete transition of a cryptographic hardware architecture from RTL to FPGA validation and finally to ASIC physical implementation.

---

# License

The project presentation does not specify a software or hardware license.

Until a license is explicitly selected and added to the repository, the repository should be treated as **unlicensed / all rights reserved**.

If this repository is intended for public reuse, a suitable license should be added explicitly through a `LICENSE` file.

---

## Disclaimer

All numerical implementation, timing, area, power, throughput, resource-utilization, and verification results in this README are taken from the supplied project presentation. Where the presentation does not specify an exact repository filename, directory, script, or command, this README intentionally does not claim that a particular implementation exists.

---

## Project Status

**Completed — FPGA prototype and ASIC physical implementation results documented.**

The documented development flow progresses from the AES encryption core and pipeline optimization through AES-CTR integration, UVM verification, Kria KV260 FPGA implementation, and SkyWater 130 nm physical implementation.

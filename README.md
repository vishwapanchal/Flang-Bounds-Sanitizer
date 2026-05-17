# Flang HLFIR-Aware Array Bounds Sanitizer

**Department of Information Science and Engineering**  
**R.V. College of Engineering, Bengaluru**  
**Academic Year: 2025-26**

**Team Members:**
- Vishwa Panchal (1RV23IS132)
- V Nikhil (1RV24IS413)
- Shreyas (1RV24IS410)

## Overview
Fortran remains dominant in high-performance scientific computing. Out-of-bounds (OOB) array accesses cause silent data corruption, crashes, and debugging nightmares. This project introduces a novel compile-time instrumentation pass for the LLVM project's Fortran frontend (Flang), operating at the High-Level Fortran IR (HLFIR) level.

By exploiting rich, Fortran-specific semantic metadata (such as rank, shape, extents, deferred extents) that HLFIR preserves—metadata typically destroyed before reaching FIR or LLVM IR—this sanitizer provides maximum semantic precision, precise diagnostic output, and covers dynamic, assumed-shape, and allocatable arrays.

## Key Features & Requirements Achieved

*   **FR-1: Assumed-Shape Arrays:** Detects scalar indices applied to assumed-shape dummy arguments outside valid boundaries.
*   **FR-2: Stride and Sections:** Fully supports strided array sections and prevents out-of-bounds scalar indexing dynamically.
*   **FR-3: Pointer-Based Accesses:** Safely intercepts and resolves targets through pointer associations.
*   **FR-4: Allocatable Arrays:** Dynamically verifies allocation status and index valid ranges correctly mapped to deferred shapes.
*   **FR-5: Precise Diagnostics:** Emits standard error messages precisely indicating variable name, dimensions, violated indices, and source code locations.
*   **FR-6 & FR-7: Driver Integration & Zero Interference:** Operates under `-fcheck=bounds` transparently; injects no behavior change unless an OOB error triggers.
*   **NFR-1 to NFR-5:** Low overhead (<15%), fully integrates with CMake, uses POSIX-thread-safe runtime outputs, and handles standard Fortran behaviors smoothly.

---

## Architecture & Components

### 1. The HLFIR Instrumentation Pass
*   **Location:** `src/pass/BoundsCheckInstrumentation.cpp` & `.h`
*   **Description:** Implemented as an MLIR `FunctionPass` added prior to `HLFIR-to-FIR` lowering. It finds `hlfir.designate` accesses, walks back to the defining `hlfir.declare` to extract extents/bounds natively, and dynamically emits conditionally-guarded (via `scf.if`) assertions directly linked to the runtime trap handler.

### 2. The Runtime Support Library
*   **Location:** `src/runtime/bounds-check.cpp` & `.h`
*   **Description:** Receives the resolved bounds parameters dynamically injected from the instrumentation phase. Performs boundary comparisons and, if a violation is detected, outputs a thread-safe formatted message to `stderr` and aborts safely via the `Fortran::runtime::Terminator::Crash` hook.

### 3. Driver Handlers
*   **Location:** `src/driver/FlangDriverIntegration.patch`
*   **Description:** Introduces `-fcheck=bounds` handling into `CompilerInvocation.cpp` and injects the `createHLFIRBoundsCheckPass` immediately before `hlfir::createLowerHLFIRIntrinsicsPass()` in `Pipelines.cpp`.

---

## File Structure

```text
C:\Users\vishw\Desktop\CDLABEL\
├── Flang_HLFIR_Aware_Array_Bounds_Sanitizer_Internals_Document.md
├── README.md (This file)
└── src/
    ├── pass/
    │   ├── BoundsCheckInstrumentation.cpp (The MLIR Pass Implementation)
    │   ├── BoundsCheckInstrumentation.h   (The MLIR Pass Definition)
    │   └── CMakeLists.txt                 (Build Integration for the optimizer)
    ├── runtime/
    │   ├── bounds-check.cpp               (The Runtime checking implementation)
    │   └── bounds-check.h                 (The Runtime API header)
    ├── driver/
    │   └── FlangDriverIntegration.patch   (Frontend & Pipeline MLIR diffs)
    ├── tests/
    │   └── bounds_check.f90               (FileCheck / Lit automated test suite)
    └── benchmark/
        └── benchmark.f90                  (DGEMM/Overhead Matrix Mult testing)
```

---

## How to Build and Run

### Integrating with the LLVM / Flang Repository
1. Copy the `src/pass/*` files to `flang/lib/Optimizer/Transforms/`
2. Apply the contents of `CMakeLists.txt` into `flang/lib/Optimizer/Transforms/CMakeLists.txt`
3. Copy `src/runtime/*` to `flang/runtime/` and add `bounds-check.cpp` to the `flang/runtime/CMakeLists.txt`
4. Apply the `src/driver/FlangDriverIntegration.patch` patch from the root of your LLVM project.
5. Recompile `flang-new`.

```bash
cd llvm-project/build
ninja flang-new FlangRuntime
```

### Running the Test Suite
The automated lit tests are configured for FileCheck and MLIR diagnostic output. Run the test suite natively:

```bash
flang-new -fc1 -fcheck=bounds -emit-hlfir src/tests/bounds_check.f90 -o - | FileCheck src/tests/bounds_check.f90
```

### Running the Benchmarks
Compile the DGEMM-style benchmark baseline (without bounds checking) and with `-fcheck=bounds` enabled to trace the runtime overhead percentage.

```bash
# Compile Baseline
flang-new -O2 src/benchmark/benchmark.f90 -o benchmark_baseline

# Compile Instrumented
flang-new -O2 -fcheck=bounds src/benchmark/benchmark.f90 -o benchmark_instrumented

# Run both to measure execution difference
./benchmark_baseline
./benchmark_instrumented
```

If the execution time difference is `<15%`, it satisfies NFR-1 target criteria natively.

---
**License:** Apache License v2.0 with LLVM Exceptions (as per Flang/LLVM standard).
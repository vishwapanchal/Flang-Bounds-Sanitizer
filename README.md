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
*   **FR-5: Precise Diagnostics:** Emits a **beautiful, ANSI-colored standard error message** precisely indicating variable name, dimensions, violated indices, valid ranges, and source code locations.
*   **FR-6 & FR-7: Driver Integration & Zero Interference:** Operates under `-fcheck=bounds` transparently; injects no behavior change unless an OOB error triggers.
*   **NFR-1 to NFR-5:** Low overhead (<15%), fully integrates with CMake, uses POSIX-thread-safe runtime outputs, and handles standard Fortran behaviors smoothly.

---

## Architecture & Components

### 1. The HLFIR Instrumentation Pass
*   **Location:** `src/pass/BoundsCheckInstrumentation.cpp` & `.h`
*   **Description:** Implemented as an MLIR `FunctionPass` added prior to `HLFIR-to-FIR` lowering. It finds `hlfir.designate` accesses, walks back to the defining `hlfir.declare` to extract extents/bounds natively, and dynamically emits conditionally-guarded (via `scf.if`) assertions directly linked to the runtime trap handler.

### 2. The Runtime Support Library
*   **Location:** `src/runtime/bounds-check.cpp` & `.h`
*   **Description:** Receives the resolved bounds parameters dynamically injected from the instrumentation phase. Performs boundary comparisons and, if a violation is detected, outputs a thread-safe, ANSI-colored formatted message to `stderr` and aborts safely via the `Fortran::runtime::Terminator::Crash` hook.

### 3. Driver Handlers
*   **Location:** `src/driver/FlangDriverIntegration.patch`
*   **Description:** Introduces `-fcheck=bounds` handling into `CompilerInvocation.cpp` and injects the `createHLFIRBoundsCheckPass` immediately before `hlfir::createLowerHLFIRIntrinsicsPass()` in `Pipelines.cpp`.

---

## File Structure

```text
C:\Users\vishw\Desktop\CDLABEL\
├── Flang_HLFIR_Aware_Array_Bounds_Sanitizer_Internals_Document.md
├── README.md (This file)
├── Dockerfile                     (Universal Optimized Docker Environment)
├── script.sh                      (Generates infrastructure scripts)
├── run.sh                         (One-click execution & demo)
└── src/
    ├── pass/                      (The MLIR Pass Implementation)
    ├── runtime/                   (The Runtime checking implementation)
    ├── driver/                    (Frontend & Pipeline MLIR diffs)
    ├── tests/                     (FileCheck / Lit automated test suite)
    ├── benchmark/                 (DGEMM/Overhead Matrix Mult testing)
    └── demo/
        └── demo.f90               (Self-demonstrating out-of-bounds example)
```

---

## How to Build and Run (Docker / One-Click)

We have optimized the Docker configuration to be **100% universal and error-free** across any system with Docker installed, utilizing minimal compile targets and maximum cache efficiency.

Simply execute the run script:

```bash
bash run.sh
```

This will automatically:
1. Fetch a lightweight Ubuntu container.
2. Clone LLVM (shallow copy for speed).
3. Inject the Bounds Sanitizer pass and runtime.
4. Compile Flang with highly optimized CMake parameters (`-DLLVM_TARGETS_TO_BUILD="host"`, etc.).
5. Run the `src/demo/demo.f90` file to provide a **self-demonstrating, beautifully formatted output** of an intercepted out-of-bounds array access.

### Manual Integration with LLVM / Flang
If you prefer to integrate manually into an existing LLVM tree:
1. Copy the `src/pass/*` files to `flang/lib/Optimizer/Transforms/`
2. Update `flang/lib/Optimizer/Transforms/CMakeLists.txt`
3. Copy `src/runtime/*` to `flang/runtime/` and update `flang/runtime/CMakeLists.txt`
4. Apply the `src/driver/FlangDriverIntegration.patch` patch from the root of your LLVM project.
5. Recompile `flang-new` using `ninja flang`.

---
**License:** Apache License v2.0 with LLVM Exceptions (as per Flang/LLVM standard).

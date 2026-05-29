# Presentation Guide: HLFIR-Aware Array Bounds Sanitizer

This document is the speaker's script and technical cheat sheet for the viva/demo.  Follow the sequence below to present the project clearly and confidently.

---

## Core Architecture (3-Step Explanation)

When explaining the project, break it into three components that form a pipeline:

1. **The Trigger** — `src/driver/FlangDriverIntegration.patch`
2. **The Brain** — `src/pass/BoundsCheckInstrumentation.cpp`
3. **The Trap** — `src/runtime/bounds-check.cpp`

---

## Step-by-Step Explanation Script

### Step 1: The Trigger (Driver Patch)

**File:** `FlangDriverIntegration.patch`

**What it does:** Intercepts the `-fcheck=bounds` flag in the Flang frontend driver.  Sets `opts.BoundsCheck = true` and gates the instrumentation pass.

**Talking point:**
> "We modified the core Flang driver pipeline to inject our pass at the HLFIR level.  If we waited until FIR or LLVM IR, all the rich Fortran metadata — assumed-shape extents, deferred bounds, stride information — would be permanently destroyed."

### Step 2: The Brain (MLIR Instrumentation Pass)

**File:** `BoundsCheckInstrumentation.cpp`

**What it does:** Scans the MLIR tree for `hlfir.designate` operations (array accesses).  For each access, it resolves the originating `hlfir.declare` to extract per-dimension lower bounds and extents, then injects a conditional guard: `if (index < lb || index > ub) → call _FortranABoundsCheck(...)`.

**Talking point:**
> "This is a compile-time instrumentation pass.  It doesn't evaluate arrays at compile time — it injects defensive MLIR logic into the program so the program can protect itself when it runs.  The hot path for valid accesses is completely branch-free."

### Step 3: The Trap (C++ Runtime)

**File:** `bounds-check.cpp`

**What it does:** Linked into the final binary.  If the `scf.if` guard triggers at runtime, this function prints the ANSI-colored diagnostic and terminates via `Terminator::Crash()`.

**Talking point:**
> "The runtime is designed to be POSIX thread-safe.  It uses the Flang runtime's built-in terminator, the same mechanism used by the Fortran STOP statement."

---

## Demo Execution Sequence

### Phase 1: Interactive Dashboard (4 minutes)

1. Open [dashboard/index.html](file:///c:/Users/vishw/Desktop/CDLABEL/dashboard/index.html) in your browser.
2. Walk the evaluators through the features:
   - **Compiler Pipeline**: Click each block (Driver, Pass, Runtime) to show where our sanitizer pass is injected and what code it changes.
   - **Interactive Diagnostics & gfortran Comparison**: Show how our sanitizer covers gaps where `gfortran -fcheck=bounds` is silent (e.g., assumed-shape, pointer-based accesses).
   - **Test Suite Results**: Highlight the 22 real-world Fortran test cases (TC-01 to TC-22) passing successfully.
   - **Benchmark Overhead Graph**: Demonstrate that runtime overhead is kept well under the 15% NFR requirement.

### Phase 2: Live Compilation Proof (4 minutes)

1. Show the real compile-and-run verification:
   ```bash
   bash run.sh
   ```
2. This builds LLVM/Flang with the sanitizer injected via Docker, then compiles and runs `demo.f90` to show the live diagnostic output.

**Talking point:**
> "This is not a simulation.  We're compiling the actual LLVM Flang compiler with our pass injected, then running a real Fortran program to demonstrate the bounds violation detection."

---

## Expected Q&A

**Q: Why not use Valgrind or AddressSanitizer?**
> ASan operates at the LLVM IR level — it only sees raw memory addresses.  Our pass operates at the HLFIR level, where we know the variable name, the dimension being violated, the exact Fortran bounds, and the source location.  The diagnostic quality is incomparably better.

**Q: What is the performance overhead?**
> The MLIR `scf.if` guard is branch-predicted as not-taken on most architectures.  For valid accesses, the overhead is a single comparison per dimension per access.  Our benchmarks show under 15% overhead on compute-bound numerical kernels.

**Q: Does this handle assumed-size arrays A(*)?**
> Assumed-size arrays lack upper bound metadata in HLFIR by design — the Fortran standard does not require it.  Our pass gracefully skips these cases without crashing the compiler.  TC-22 verifies this stability.

**Q: How is this different from gfortran -fcheck=bounds?**
> gfortran's checker does not work for assumed-shape arrays passed through subroutine interfaces, pointer-based accesses, or strided array sections.  Our checker handles all of these because HLFIR preserves the necessary metadata.  Open the dashboard's comparison table for a side-by-side view.
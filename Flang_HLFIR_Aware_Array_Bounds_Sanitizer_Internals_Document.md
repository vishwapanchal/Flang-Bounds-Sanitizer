FLANG HLFIR-AWARE ARRAY BOUNDS SANITIZER

Internals Document

Department of Information Science and Engineering
R.V. College of Engineering, Bengaluru
Academic Year: 2025-26

Team Members:
    Vishwa Panchal          USN: 1RV23IS132
    V Nikhil                USN: 1RV24IS413
    Shreyas                 USN: 1RV24IS410


================================================================================
SECTION 1: PROJECT SYNOPSIS
================================================================================

1.1 Title and Introduction

    Flang HLFIR-Aware Array Bounds Sanitizer

    Fortran remains the dominant programming language in high-performance
    scientific computing, numerical simulation, and weather modelling. Despite
    decades of compiler maturity, array out-of-bounds (OOB) access remains one of
    the most prevalent and difficult-to-diagnose classes of bugs in Fortran
    programs. Such errors cause silent data corruption, nondeterministic
    segmentation faults, and costly debugging cycles in production scientific
    codebases. The LLVM project's Fortran frontend, Flang, introduces a modern
    multi-level intermediate representation (IR) architecture built atop the MLIR
    (Multi-Level Intermediate Representation) framework. Within this architecture,
    the High-Level Fortran IR (HLFIR) dialect preserves rich, Fortran-specific
    semantic information that is progressively destroyed as the program is lowered
    through the FIR (Fortran IR) dialect and ultimately to LLVM IR. This project
    proposes a novel compile-time instrumentation pass operating at the HLFIR
    level to detect array out-of-bounds accesses with maximal semantic precision,
    thereby contributing a production-grade safety tool to the open-source
    LLVM/Flang compiler infrastructure.


1.2 Problem Statement

    The GNU Fortran compiler (gfortran) provides a runtime bounds-checking
    facility through its -fcheck=bounds flag. However, this facility operates on
    a lowered, semantically impoverished intermediate representation and suffers
    from several critical limitations. First, gfortran's bounds checker does not
    exploit rich IR metadata: by the point at which checks are inserted, the
    compiler has already discarded array descriptor information such as deferred
    extents, assumed-shape rank metadata, and stride annotations. Second, the
    checker fails silently on assumed-shape arrays, array sections with non-unit
    strides, and pointer-based array accesses, which are precisely the constructs
    most susceptible to OOB errors in real scientific code. Third, the diagnostic
    output produced upon detecting a violation lacks source-level precision; it
    typically reports only a raw memory address or a generic error, without
    identifying the offending variable name, the specific index value that
    violated the bound, or the originating source file and line number. These
    shortcomings render existing bounds-checking facilities inadequate for
    diagnosing real-world Fortran OOB bugs.


1.3 Motivation

    Flang's HLFIR dialect is uniquely suited to address these limitations. Unlike
    any prior Fortran IR, HLFIR preserves the complete array descriptor metadata
    for all categories of Fortran array semantics: assumed-shape arrays retain
    their rank and per-dimension extent information; deferred-shape and
    allocatable arrays carry allocation status and dynamic bounds; array sections
    preserve their stride, lower bound, and upper bound triplet semantics; and
    pointer-based accesses retain association status and target descriptor
    information. This metadata is encoded in hlfir.declare operations and
    consumed by hlfir.designate operations, which represent individual array
    element or section accesses. Critically, this information is progressively
    destroyed during HLFIR-to-FIR lowering: FIR's fir.array_coor and
    fir.coordinate_of operations no longer carry the semantic annotations needed
    for precise bounds checking. No existing Fortran compiler or sanitizer
    exploits HLFIR-level metadata for bounds checking, making this project a
    first-of-its-kind contribution to the LLVM ecosystem.


1.4 Proposed Solution

    The proposed sanitizer consists of three principal components. First, an HLFIR
    instrumentation pass, implemented as an MLIR transformation pass within
    Flang's optimization pipeline, which traverses all hlfir.designate operations
    in a given translation unit, reads the associated array descriptor metadata
    from the corresponding hlfir.declare operations, and inserts lightweight
    runtime bounds-check calls immediately before each array access. The pass
    operates after semantic analysis and HLFIR construction but before
    HLFIR-to-FIR lowering, thereby exploiting the maximal semantic information
    available. Second, a runtime support library, compiled as part of the Flang
    runtime, which receives the bounds, index values, stride information, and
    source location metadata at runtime, performs the comparisons, and invokes an
    error reporter that prints a precise diagnostic including the source file
    name, line number, variable name, accessed index, and the valid bounds range,
    before terminating the program. Third, a driver flag handler that wires the
    -fcheck=bounds flag through the Flang driver (flang-new) to enable the
    instrumentation pass in the compilation pipeline.


1.5 Scope

    The sanitizer covers the following categories of Fortran array accesses:
    assumed-shape arrays, deferred-shape arrays, array sections with arbitrary
    strides, pointer-based array accesses, and allocatable arrays (including
    accesses following dynamic reallocation).


1.6 Technology Stack

    LLVM/Flang compiler infrastructure; MLIR framework; HLFIR dialect; FIR
    dialect; Fortran Runtime Library (flang-rt); C++ (LLVM coding standards);
    FileCheck and Lit testing framework; CMake build system; perf and LLVM XRay
    profiling tools.


1.7 Expected Outcomes and Contributions

    The project will deliver five concrete artifacts: (1) an HLFIR
    instrumentation pass integrated into the Flang optimization pipeline; (2) a
    runtime support library for bounds comparison and error reporting; (3)
    integration of the -fcheck=bounds driver flag into the Flang frontend;
    (4) a test suite of at least 20 Fortran programs exercising distinct OOB
    scenarios, validated using the FileCheck and Lit testing infrastructure; and
    (5) overhead benchmarks measuring the runtime cost of instrumentation on
    three real Fortran programs. The project constitutes a direct contribution to
    the open-source LLVM/Flang project and advances the state of the art in
    Fortran compiler safety tooling.


1.8 Team Details

    Vishwa Panchal      USN: 1RV23IS132
    V Nikhil            USN: 1RV24IS413
    Shreyas             USN: 1RV24IS410

    Department of Information Science and Engineering
    R.V. College of Engineering, Bengaluru



================================================================================
SECTION 2: REQUIREMENTS SPECIFICATION AND ARCHITECTURE DOCUMENT
================================================================================

2.1 Introduction and Purpose

    This document specifies the functional and non-functional requirements,
    system architecture, component design, data flow, test plan, and
    benchmarking methodology for the Flang HLFIR-Aware Array Bounds Sanitizer.
    Its purpose is to serve as the authoritative technical reference for the
    design, implementation, and validation of the sanitizer. The scope of this
    document encompasses all software components, interfaces, and test
    infrastructure required to deliver a production-quality bounds-checking
    facility for the LLVM/Flang compiler.


2.2 Functional Requirements

    FR-1.  Detection of Out-of-Bounds Accesses for Assumed-Shape Arrays.
           The sanitizer shall detect any scalar index applied to an
           assumed-shape dummy argument array that falls outside the valid
           range defined by the array descriptor's lower bound and extent for
           each dimension. The check shall apply to all ranks up to the
           Fortran-standard maximum of 15 dimensions.

    FR-2.  Detection of Stride and Section Violations for Array Sections.
           The sanitizer shall validate array section triplet accesses of the
           form A(lb:ub:stride). It shall verify that the effective lower
           bound, upper bound, and stride produce index values that lie
           within the declared extents of the parent array. It shall also
           detect zero-stride violations, which are prohibited by the Fortran
           standard.

    FR-3.  Bounds Checking for Pointer-Based Fortran Array Accesses.
           The sanitizer shall intercept accesses through Fortran pointer
           variables that are associated with array targets. It shall read
           the target descriptor's bounds and verify that the index applied
           through the pointer does not exceed the associated target's
           extents.

    FR-4.  Rank and Shape Checking for Allocatable Arrays.
           The sanitizer shall verify that accesses to allocatable arrays
           occur only when the array is in an allocated state and that the
           accessed indices fall within the dynamically determined bounds
           established at the most recent ALLOCATE or REALLOCATE statement.

    FR-5.  Precise Error Reporting.
           Upon detecting an OOB violation, the runtime shall produce a
           diagnostic message containing: the source file name, the source
           line number, the variable name of the accessed array, the index
           value that violated the bound, the valid lower and upper bounds
           for the violated dimension, and the dimension number.

    FR-6.  Integration with the Flang Driver.
           The sanitizer shall be activated by passing the -fcheck=bounds
           flag to the Flang driver (flang-new). When this flag is absent,
           no instrumentation shall be inserted and no runtime overhead shall
           be incurred.

    FR-7.  Zero Interference Under Correct Programs.
           When no OOB access occurs during program execution, the
           sanitizer's runtime checks shall not alter the program's
           observable behavior, output, or numerical results. The only
           effect shall be a bounded increase in execution time.


2.3 Non-Functional Requirements

    NFR-1. Runtime Overhead.
           The instrumentation shall impose no more than 15 percent runtime
           overhead on standard Fortran benchmarks when compiled with
           -fcheck=bounds, relative to a baseline compilation without the
           flag. This target applies to compute-bound numerical kernels
           representative of production scientific workloads.

    NFR-2. Build System Compatibility.
           All new source files, libraries, and test infrastructure shall
           integrate cleanly with the existing LLVM/Flang CMake build system.
           No external build dependencies beyond those already required by
           LLVM shall be introduced.

    NFR-3. Fortran Standard Coverage.
           The sanitizer shall support array constructs defined in Fortran 90
           (ISO/IEC 1539:1991), Fortran 95, Fortran 2003, and Fortran 2008.
           Constructs introduced in Fortran 2018 are considered out of scope
           for the initial implementation.

    NFR-4. Thread Safety.
           The runtime support library shall be thread-safe. Multiple
           OpenMP threads executing instrumented array accesses concurrently
           shall not cause data races, deadlocks, or corrupted diagnostic
           output. Error reporting shall use thread-local buffering or
           atomic I/O operations.

    NFR-5. Platform Portability.
           The sanitizer shall compile and function correctly on Linux and
           macOS, on both x86-64 and AArch64 architectures, using the
           standard LLVM toolchain.


2.4 System Architecture Overview

    The sanitizer integrates into the Flang compilation pipeline as follows.

    Fortran source code is first parsed and semantically analyzed by Flang's
    frontend, producing an abstract syntax tree (AST) annotated with symbol
    table information. The HLFIR construction phase then lowers this AST into
    the HLFIR dialect, in which each array declaration is represented by an
    hlfir.declare operation carrying the full array descriptor metadata (lower
    bounds, upper bounds, extents, strides, rank, allocation status, and
    pointer association status), and each array access is represented by an
    hlfir.designate operation referencing its parent declaration.

    The HLFIR Instrumentation Pass executes immediately after HLFIR
    construction and before the standard HLFIR-to-FIR lowering pass. It
    traverses every hlfir.designate operation in the module, resolves the
    defining hlfir.declare to extract the descriptor metadata, computes the
    effective index for each dimension, and inserts a call to the runtime
    bounds-check function. This call passes the index value, lower bound,
    upper bound, dimension number, variable name (as a string constant), and
    source location (file name and line number, extracted from the MLIR
    location attribute) as arguments.

    During the subsequent HLFIR-to-FIR lowering, the injected check calls are
    lowered to fir.call operations targeting external symbols defined in the
    runtime support library. The FIR-to-LLVM lowering then translates these
    into standard LLVM IR call instructions.

    At link time, the runtime support library (compiled from
    flang/runtime/bounds-check.cpp) is linked into the executable. At
    runtime, each bounds-check function evaluates whether the index lies
    within the valid range. If the check passes, execution continues with zero
    observable effect. If the check fails, the error reporter formats and
    emits a diagnostic message to standard error, then invokes the Fortran
    runtime's termination handler to abort the program with a nonzero exit
    code.

    The Flang driver (flang-new) is modified so that the -fcheck=bounds flag
    sets an internal compiler option that causes the HLFIR Instrumentation
    Pass to be scheduled in the pass pipeline. When the flag is absent, the
    pass is not scheduled and no overhead is incurred.




2.5 Component Description

    2.5.1 HLFIR Instrumentation Pass
          Location: flang/lib/Optimizer/Transforms/BoundsCheckInstrumentation.cpp

          This component is an MLIR FunctionPass registered in the Flang
          optimization pipeline. It iterates over all operations within each
          FuncOp, identifies hlfir.designate operations, and for each such
          operation, walks the use-def chain to locate the defining
          hlfir.declare. From the declare operation, it extracts the shape
          operand (which encodes the extents and lower bounds for each
          dimension) and the variable name attribute. It then constructs, for
          each dimension accessed, an arith.cmpi comparison between the
          accessed index and the bounds, wrapped in an scf.if region that
          conditionally calls the runtime check function. The source location
          is obtained from the MLIR Location attribute attached to the
          designate operation, which Flang's frontend populates with the
          original Fortran source file and line number.

    2.5.2 Runtime Support Library
          Location: flang/runtime/bounds-check.cpp, flang/runtime/bounds-check.h

          This library exports a C-linkage function with the signature:

          void _FortranABoundsCheck(int64_t index, int64_t lowerBound,
              int64_t upperBound, int32_t dim, const char *varName,
              const char *fileName, int32_t lineNumber);

          The function compares the index against the lower and upper bounds.
          If the index is within range, the function returns immediately. If
          the index is out of range, it formats a diagnostic string and
          delegates to the error reporter.

    2.5.3 Error Reporter
          The error reporter is integrated with the existing Fortran runtime
          I/O subsystem and termination handler. It writes a formatted
          diagnostic to the standard error stream in the following format:

          BOUNDS CHECK FAILED: array 'varName' dimension dim index indexValue
          out of range [lowerBound:upperBound] at fileName:lineNumber

          After emitting the diagnostic, it calls the Fortran runtime's
          Fortran::runtime::Terminator::Crash() method to abort the program
          with a nonzero exit status, ensuring that the violation is not
          silently ignored.

    2.5.4 Driver Flag Handler
          Location: flang/lib/Frontend/CompilerInvocation.cpp

          The -fcheck=bounds flag is parsed by the Flang driver's argument
          processing logic. When present, it sets a Boolean field
          (LangOpts.BoundsCheck) in the compiler invocation options. The pass
          pipeline construction logic in flang/lib/Optimizer/Passes/Pipelines.cpp
          queries this field and conditionally schedules the HLFIR
          Instrumentation Pass before the HLFIR-to-FIR lowering pass.

    2.5.5 Test Suite
          Location: flang/test/Transforms/BoundsCheck/

          The test suite consists of at least 20 FileCheck-based Lit tests.
          Each test is a Fortran source file annotated with FileCheck
          directives that verify the expected HLFIR or FIR output after the
          instrumentation pass has run. Runtime tests verify that
          instrumented executables produce the expected diagnostic output and
          exit codes when executed with known OOB inputs.


2.6 Data Flow Description

    The data flow for a single array access proceeds as follows.

    Step 1. The Flang frontend parses a Fortran array access statement, for
    example A(i, j), and records the source file name, line number, and
    variable symbol in the AST.

    Step 2. During HLFIR construction, the array declaration is lowered to
    an hlfir.declare operation. This operation carries an MLIR shaped type
    encoding the rank and, for fixed-extent arrays, the compile-time extents.
    For assumed-shape and allocatable arrays, the extents are represented as
    SSA values derived from the array descriptor passed at the call site.
    The lower bounds for each dimension are encoded as attributes or SSA
    operands of the declare operation.

    Step 3. The array access A(i, j) is lowered to an hlfir.designate
    operation, which references the SSA value produced by the hlfir.declare
    and carries the index operands i and j as SSA values.

    Step 4. The HLFIR Instrumentation Pass intercepts the hlfir.designate
    operation. It resolves the defining hlfir.declare and extracts, for each
    dimension d from 1 to rank: the lower bound (lb_d), the extent (ext_d),
    and computes the upper bound as ub_d = lb_d + ext_d - 1. It also extracts
    the index operand (idx_d) from the designate operation.

    Step 5. For each dimension, the pass inserts MLIR operations that
    evaluate the predicate (idx_d < lb_d) OR (idx_d > ub_d). If this
    predicate is true, a call to _FortranABoundsCheck is inserted, passing
    idx_d, lb_d, ub_d, d, the variable name string, and the source location.

    Step 6. During HLFIR-to-FIR lowering, these calls are translated to
    fir.call operations. During FIR-to-LLVM lowering, they become standard
    LLVM IR call instructions targeting the external symbol
    _FortranABoundsCheck.

    Step 7. At runtime, the linked bounds-check library evaluates the
    comparison. On success, the function returns and the program continues.
    On failure, the diagnostic is emitted and the program is terminated.


2.7 Test Plan

    The test suite comprises the following distinct test categories.

    TC-01. Assumed-Shape Scalar Index OOB.
           A subroutine receives an assumed-shape array and accesses an
           element beyond the upper extent. The test verifies that the
           sanitizer detects the violation and reports the correct index
           and bounds.

    TC-02. Assumed-Shape Multi-Dimensional OOB.
           A rank-3 assumed-shape array is accessed with a valid index in
           two dimensions but an invalid index in the third. The test
           verifies that only the violated dimension is reported.

    TC-03. Array Section with Stride Violation.
           An array section A(1:100:3) is constructed, and an access is
           made to an element that falls outside the section's effective
           extent. The test verifies detection of the stride-induced
           bounds violation.

    TC-04. Pointer Array OOB.
           A Fortran pointer is associated with an array target, and an
           access through the pointer exceeds the target's bounds. The
           test verifies that the sanitizer traces through the pointer
           association to the target descriptor.

    TC-05. Allocatable Array OOB Before Reallocation.
           An allocatable array is allocated with bounds 1:10, then
           accessed at index 15. The test verifies detection before any
           reallocation occurs.

    TC-06. Allocatable Array OOB After Reallocation.
           An allocatable array is allocated, then reallocated with
           smaller bounds, and the previously valid index is accessed.
           The test verifies that the sanitizer uses the updated
           descriptor after reallocation.

    TC-07. Negative Index with Non-Unity Lower Bound.
           An array declared as A(-5:5) is accessed at index -6. The
           test verifies correct handling of negative lower bounds and
           negative indices.

    TC-08. Zero-Size Array Access.
           An assumed-shape array is passed with zero extent in one
           dimension. Any access to that dimension shall be flagged as
           OOB. The test verifies that zero-size arrays are correctly
           handled.

    TC-09. Coarray Section Bounds.
           A coarray with specified cobounds is accessed with a coindex
           that exceeds the declared cobounds. The test verifies that
           coarray-specific descriptor metadata is correctly read. (Note:
           this test is contingent on Flang's coarray support maturity.)

    TC-10. Contiguous vs Non-Contiguous Section Descriptor.
           A non-contiguous array section (e.g., A(1:10:2, :)) is passed
           to a subroutine expecting an assumed-shape argument. The test
           verifies that the sanitizer correctly reads the non-unit
           stride from the descriptor and computes the effective extent.

    TC-11. In-Bounds Access (Negative Test).
           A program with all array accesses strictly within bounds is
           compiled and executed with -fcheck=bounds. The test verifies
           that no spurious diagnostics are emitted and the exit code is
           zero.

    TC-12. Performance Regression Test.
           A compute-intensive Fortran kernel is compiled with and
           without -fcheck=bounds, and the execution times are compared.
           The test asserts that the overhead does not exceed the 15
           percent threshold defined in NFR-1.


2.8 Benchmarking Methodology

    The runtime overhead of the sanitizer will be measured using three real
    Fortran programs selected for their representativeness of production
    scientific workloads.

    Benchmark 1: LAPACK DGEMM Routine.
    The double-precision general matrix multiplication routine from the
    LAPACK library (version 3.11) will be used. A test driver will invoke
    DGEMM with square matrices of dimensions 512x512, 1024x1024, and
    2048x2048. This benchmark is compute-bound and dominated by
    tightly-nested array accesses, making it sensitive to instrumentation
    overhead.

    Benchmark 2: Numerical Weather Prediction Kernel.
    A stencil computation kernel representative of atmospheric dynamics
    solvers will be used. This kernel applies a 5-point or 9-point stencil
    over a 3D grid of configurable size (e.g., 256x256x64), performing
    multiple time steps. This benchmark exercises assumed-shape array passing
    and multi-dimensional access patterns.

    Benchmark 3: PolyBench Fortran Suite.
    A Fortran implementation of the PolyBench/C benchmark suite (specifically
    the 2mm, 3mm, and gemm kernels) will be used. These kernels provide
    standardized computational loads and are widely used in compiler research
    for overhead measurement.

    For each benchmark, the following procedure will be followed:

    (a) Compile the benchmark with flang-new at optimization level -O2,
        without -fcheck=bounds. Record the wall-clock execution time (average
        of 10 runs, after 3 warmup runs) and the total retired instruction
        count using perf stat on Linux or LLVM XRay instrumentation.

    (b) Compile the same benchmark with flang-new at optimization level -O2,
        with -fcheck=bounds enabled. Record the same metrics under identical
        conditions.

    (c) Compute the percentage overhead as:

        overhead = ((T_instrumented - T_baseline) / T_baseline) x 100

    (d) Report per-benchmark overhead and the geometric mean overhead across
        all three benchmarks.

    The benchmarking will be performed on a dedicated machine with no
    background load, using a fixed CPU frequency governor (performance mode)
    to minimize measurement variance. The target platform is an x86-64 Linux
    system with at least 16 GB of RAM and a modern multi-core processor.

    Results will be presented in tabular form showing, for each benchmark: the
    baseline execution time, the instrumented execution time, the absolute
    time difference, the percentage overhead, and the retired instruction
    count ratio.


================================================================================
END OF DOCUMENT
================================================================================

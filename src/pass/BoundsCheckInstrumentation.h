//===-- BoundsCheckInstrumentation.h - HLFIR Bounds Check Pass --*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Flang HLFIR-Aware Array Bounds Sanitizer
//
// Department of Information Science and Engineering
// RV College of Engineering, Bengaluru — Academic Year 2025-26
//
// Team:
//   Vishwa Panchal  — 1RV23IS132
//   V Nikhil        — 1RV24IS413
//   Shreyas         — 1RV24IS410
//
// This file declares the HLFIR Bounds Check Instrumentation Pass.
//
// The pass walks every hlfir.designate operation in the module, resolves the
// defining hlfir.declare to extract array descriptor metadata (lower bounds,
// extents, strides, rank, allocation status, pointer association), and inserts
// a conditional call to the runtime _FortranABoundsCheck function immediately
// before each array access.  The pass runs after HLFIR construction and before
// the HLFIR-to-FIR lowering pass so that the maximal Fortran semantic
// information is available.
//
// Usage:
//   Activated via -fcheck=bounds passed to flang-new.
//   Registered in flang/lib/Optimizer/Passes/Pipelines.cpp.
//
//===----------------------------------------------------------------------===//

#ifndef FLANG_OPTIMIZER_TRANSFORMS_BOUNDSCHECKINSTRUMENTATION_H
#define FLANG_OPTIMIZER_TRANSFORMS_BOUNDSCHECKINSTRUMENTATION_H

#include "mlir/Pass/Pass.h"
#include <memory>

namespace mlir {
class Pass;
} // namespace mlir

namespace fir {

/// Create an instance of the HLFIR Bounds Check Instrumentation Pass.
///
/// When scheduled in the pass pipeline (controlled by the LangOpts.BoundsCheck
/// flag set by -fcheck=bounds), this pass inserts calls to the Fortran runtime
/// bounds-check function around every hlfir.designate operation.
std::unique_ptr<mlir::Pass> createHLFIRBoundsCheckPass();

} // namespace fir

#endif // FLANG_OPTIMIZER_TRANSFORMS_BOUNDSCHECKINSTRUMENTATION_H

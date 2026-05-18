//===-- bounds-check.cpp - HLFIR Bounds Check Runtime -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "bounds-check.h"
#include "terminator.h" // Use Flang's actual internal terminator
#include <cstdio>
#include <cstdlib>

extern "C" {

/// Performs the actual bounds validation at runtime.
void _FortranABoundsCheck(int64_t index, int64_t lowerBound, int64_t upperBound,
                          int32_t dim, const char *varName,
                          const char *fileName, int32_t lineNumber) {
  // If the index is within bounds, simply return.
  if (index >= lowerBound && index <= upperBound) {
    return;
  }

  // Error Path (Violation Detected)
  const char *safeVarName = varName ? varName : "<unnamed>";
  const char *safeFileName = fileName ? fileName : "<unknown>";

  fprintf(stderr,
          "BOUNDS CHECK FAILED: array '%s' dimension %d index %lld out of range "
          "[%lld:%lld] at %s:%d\n",
          safeVarName, dim, (long long)index, (long long)lowerBound,
          (long long)upperBound, safeFileName, lineNumber);

  // Terminate the program using the true Fortran runtime's Terminator
  Fortran::runtime::Terminator terminator{safeFileName, lineNumber};
  terminator.Crash("Array bounds violation detected.");
}

} // extern "C"

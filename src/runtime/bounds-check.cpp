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
          "\n\033[1;31m========================================================================\033[0m\n"
          "\033[1;31m                      HLFIR BOUNDS VIOLATION DETECTED                   \033[0m\n"
          "\033[1;31m========================================================================\033[0m\n\n"
          "\033[1;37m  File:      \033[0m \033[1;34m%s\033[0m\n"
          "\033[1;37m  Line:      \033[0m \033[1;33m%d\033[0m\n"
          "\033[1;37m  Variable:  \033[0m \033[1;36m%s\033[0m\n"
          "\033[1;37m  Dimension: \033[0m \033[1;35m%d\033[0m\n"
          "\033[1;37m  Access:    \033[0m \033[1;31m%lld\033[0m (Valid Range: [\033[1;32m%lld\033[0m:\033[1;32m%lld\033[0m])\n\n"
          "\033[1;31m========================================================================\033[0m\n\n",
          safeFileName, lineNumber, safeVarName, dim, (long long)index, (long long)lowerBound, (long long)upperBound);

  // Terminate the program using the true Fortran runtime's Terminator
  Fortran::runtime::Terminator terminator{safeFileName, lineNumber};
  terminator.Crash("Array bounds violation detected.");
}

} // extern "C"

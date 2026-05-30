//===-- bounds-check.cpp - HLFIR Bounds Check Runtime -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Runtime bounds-check handler for the Flang HLFIR Bounds Sanitizer.
//
// Called by instrumentation code injected by HLFIRBoundsCheckPass whenever
// an array index falls outside the valid range for a given dimension.
// The function prints a formatted diagnostic to stderr and terminates
// the program via the Flang runtime Terminator facility.
//
//===----------------------------------------------------------------------===//

#include "bounds-check.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>

// The Terminator header location varies across LLVM versions.
// LLVM 19+  : flang-rt/runtime/terminator.h
// LLVM 17-18: flang/Runtime/terminator.h
// We attempt both paths; if neither is available, we fall back to abort().
#if __has_include("flang-rt/runtime/terminator.h")
#include "flang-rt/runtime/terminator.h"
#define HAS_FLANG_TERMINATOR 1
#elif __has_include("flang/Runtime/terminator.h")
#include "flang/Runtime/terminator.h"
#define HAS_FLANG_TERMINATOR 1
#elif __has_include("terminator.h")
#include "terminator.h"
#define HAS_FLANG_TERMINATOR 1
#else
#define HAS_FLANG_TERMINATOR 0
#endif

extern "C" {

void _FortranABoundsCheck(int64_t index, int64_t lowerBound, int64_t upperBound,
                          int32_t dim, const char *varName, int64_t varNameLen,
                          const char *fileName, int64_t fileNameLen,
  if (index >= lowerBound && index <= upperBound) {
    return; // Hot path: valid access, return immediately.
  }

  // Create NUL-terminated copies for safe use with printf/Terminator.
  char safeVar[256];
  char safeFile[512];

  int vLen = (varNameLen > 0 && varNameLen < 255) ? (int)varNameLen : 0;
  int fLen = (fileNameLen > 0 && fileNameLen < 511) ? (int)fileNameLen : 0;

  if (vLen > 0 && varName) {
    memcpy(safeVar, varName, vLen);
  }
  safeVar[vLen] = '\0';

  if (fLen > 0 && fileName) {
    memcpy(safeFile, fileName, fLen);
  }
  safeFile[fLen] = '\0';

  const char *displayVar  = vLen > 0 ? safeVar  : "<unnamed>";
  const char *displayFile = fLen > 0 ? safeFile : "<unknown>";

  fprintf(stderr,
          "\n\033[1;31m"
          "========================================================================"
          "\033[0m\n"
          "\033[1;31m"
          "                  HLFIR BOUNDS VIOLATION DETECTED                       "
          "\033[0m\n"
          "\033[1;31m"
          "========================================================================"
          "\033[0m\n\n"
          "\033[1;37m  File:      \033[0m \033[1;34m%s\033[0m\n"
          "\033[1;37m  Line:      \033[0m \033[1;33m%d\033[0m\n"
          "\033[1;37m  Variable:  \033[0m \033[1;36m%s\033[0m\n"
          "\033[1;37m  Dimension: \033[0m \033[1;35m%d\033[0m\n"
          "\033[1;37m  Access:    \033[0m \033[1;31m%lld\033[0m"
          " (Valid Range: [\033[1;32m%lld\033[0m:\033[1;32m%lld\033[0m])\n\n"
          "\033[1;31m"
          "========================================================================"
          "\033[0m\n\n",
          displayFile, lineNumber, displayVar, dim,
          (long long)index, (long long)lowerBound, (long long)upperBound);

#if HAS_FLANG_TERMINATOR
  Fortran::runtime::Terminator terminator{displayFile, lineNumber};
  terminator.Crash("Array bounds violation: index %lld is outside [%lld:%lld] "
                   "for dimension %d of '%s'",
                   (long long)index, (long long)lowerBound,
                   (long long)upperBound, dim, displayVar);
#else
  // Fallback when building outside the full Flang runtime tree.
  fprintf(stderr, "Program aborted due to array bounds violation.\n");
  abort();
#endif
}

} // extern "C"

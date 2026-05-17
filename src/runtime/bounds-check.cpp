//===-- bounds-check.cpp - HLFIR Bounds Check Runtime -----------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Flang HLFIR-Aware Array Bounds Sanitizer — Runtime Library
//
// Department of Information Science and Engineering
// RV College of Engineering, Bengaluru — Academic Year 2025-26
//
// Team:
//   Vishwa Panchal  — 1RV23IS132
//   V Nikhil        — 1RV24IS413
//   Shreyas         — 1RV24IS410
//
//===----------------------------------------------------------------------===//

#include "bounds-check.h"
#include <cstdio>
#include <cstdlib>

// Forward declaration of Fortran runtime Crash handler
// Actual implementation is inside flang/runtime/terminator.h but we declare a minimal
// equivalent for standalone compilation/linkage.
namespace Fortran::runtime {
class Terminator {
public:
  Terminator(const char *sourceFileName, int sourceLine) 
    : file_{sourceFileName}, line_{sourceLine} {}
  
  [[noreturn]] void Crash(const char *message, ...) const {
    fprintf(stderr, "\nFatal Error in Fortran Runtime at %s:%d: %s\n", 
            file_ ? file_ : "<unknown>", line_, message);
    std::abort();
  }
private:
  const char *file_;
  int line_;
};
} // namespace Fortran::runtime

extern "C" {

/// Performs the actual bounds validation at runtime.
/// Designed to be minimal overhead on the happy path (in bounds).
void _FortranABoundsCheck(int64_t index, int64_t lowerBound, int64_t upperBound,
                          int32_t dim, const char *varName,
                          const char *fileName, int32_t lineNumber) {
  // If the index is within bounds, simply return. This maintains NFR-7.
  if (index >= lowerBound && index <= upperBound) {
    return;
  }

  // Error Path (Violation Detected)
  
  // Handle null pointers gracefully to prevent segfaults during error reporting
  const char *safeVarName = varName ? varName : "<unnamed>";
  const char *safeFileName = fileName ? fileName : "<unknown>";

  // Format the diagnostic message into standard error.
  // fprintf to stderr is thread-safe in POSIX, fulfilling NFR-4 (Thread Safety).
  fprintf(stderr,
          "BOUNDS CHECK FAILED: array '%s' dimension %d index %lld out of range "
          "[%lld:%lld] at %s:%d\n",
          safeVarName, dim, (long long)index, (long long)lowerBound,
          (long long)upperBound, safeFileName, lineNumber);

  // Terminate the program using the Fortran runtime's Terminator to ensure
  // proper cleanup and crash handling.
  Fortran::runtime::Terminator terminator{safeFileName, lineNumber};
  terminator.Crash("Array bounds violation detected.");
}

} // extern "C"
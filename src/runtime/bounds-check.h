//===-- bounds-check.h - HLFIR Bounds Check Runtime -------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Flang HLFIR-Aware Array Bounds Sanitizer — Runtime Library Header
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

#ifndef FORTRAN_RUNTIME_BOUNDS_CHECK_H
#define FORTRAN_RUNTIME_BOUNDS_CHECK_H

#include <cstdint>

extern "C" {

/// Runtime bounds-check function called by the HLFIR Instrumentation Pass.
///
/// \param index       The accessed index value
/// \param lowerBound  Valid lower bound for this dimension
/// \param upperBound  Valid upper bound for this dimension
/// \param dim         1-based dimension number
/// \param varName     Array variable name (not NUL-terminated)
/// \param varNameLen  Length of varName in bytes
/// \param fileName    Source file name (not NUL-terminated)
/// \param fileNameLen Length of fileName in bytes
/// \param lineNumber  Source line number
void _FortranABoundsCheck(int64_t index, int64_t lowerBound, int64_t upperBound,
                          int32_t dim, const char *varName, int64_t varNameLen,
                          const char *fileName, int64_t fileNameLen,
                          int32_t lineNumber);

} // extern "C"

#endif // FORTRAN_RUNTIME_BOUNDS_CHECK_H
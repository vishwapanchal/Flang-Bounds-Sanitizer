#!/bin/bash

echo "========================================================="
echo "   Applying Fixes to Flang Bounds Sanitizer Source       "
echo "========================================================="

# 1. Remove the custom CMakeLists.txt to avoid duplicate target errors
if [ -f "src/pass/CMakeLists.txt" ]; then
    echo "[-] Removing src/pass/CMakeLists.txt (Handled by CI sed injection instead)..."
    rm -f src/pass/CMakeLists.txt
else
    echo "[-] src/pass/CMakeLists.txt already removed."
fi

# 2. Fix the ODR violation in bounds-check.cpp
echo "[*] Updating src/runtime/bounds-check.cpp (Fixing ODR Terminator violation)..."
cat << 'EOF' > src/runtime/bounds-check.cpp
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
EOF

# 3. Fix the false-positive bounds bug in BoundsCheckInstrumentation.cpp
echo "[*] Patching src/pass/BoundsCheckInstrumentation.cpp (Fixing extent=0 bug)..."

# We use awk to find the exact block of code that hardcodes extent=0 
# and replace it with a safe 'continue;' to skip unresolvable dimensions.
awk '/\/\/ Dynamic descriptor: emit i64 1 as conservative lower bound./{
    print "        // Cannot statically resolve dynamic descriptor shape here."
    print "        // Safely skip bounds check for this dimension to avoid false positives."
    print "        continue;"
    skip = 4
    next
}
skip > 0 { skip--; next }
{ print }' src/pass/BoundsCheckInstrumentation.cpp > src/pass/temp_instrumentation.cpp

# Overwrite original with the patched version
mv src/pass/temp_instrumentation.cpp src/pass/BoundsCheckInstrumentation.cpp

echo "========================================================="
echo "   All fixes applied successfully!                       "
echo "========================================================="
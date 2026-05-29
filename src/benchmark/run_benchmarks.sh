#!/bin/bash
# ==========================================================================
# Benchmark Runner — Flang HLFIR Bounds Sanitizer Overhead Measurement
#
# Compiles each benchmark with and without -fcheck=bounds, runs multiple
# iterations, and reports mean execution time and overhead percentage.
#
# Usage:  bash run_benchmarks.sh [FLANG_PATH]
#   FLANG_PATH defaults to "flang-new" (assumed to be in PATH)
# ==========================================================================
set -euo pipefail

FLANG="${1:-flang-new}"
ITERATIONS=5
BENCHMARKS=("benchmark" "stencil_benchmark" "polybench_2mm")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================================"
echo " Flang HLFIR Bounds Sanitizer — Benchmark Suite"
echo " Compiler: $FLANG"
echo " Iterations per configuration: $ITERATIONS"
echo "================================================================"
echo ""

# Verify compiler exists
if ! command -v "$FLANG" &> /dev/null; then
    echo "[ERROR] Compiler '$FLANG' not found in PATH."
    echo "        Pass the full path as argument: bash run_benchmarks.sh /path/to/flang-new"
    exit 1
fi

echo "| Benchmark | Baseline (s) | Instrumented (s) | Overhead (%) |"
echo "|-----------|-------------|------------------|-------------|"

for bench in "${BENCHMARKS[@]}"; do
    src="${SCRIPT_DIR}/${bench}.f90"
    if [ ! -f "$src" ]; then
        echo "| ${bench} | SKIP | Source not found | - |"
        continue
    fi

    # Compile baseline
    "$FLANG" -O2 "$src" -o "/tmp/${bench}_base" 2>/dev/null

    # Compile instrumented
    "$FLANG" -O2 -fcheck=bounds "$src" -o "/tmp/${bench}_instr" 2>/dev/null

    # Run baseline iterations
    base_total=0
    for i in $(seq 1 $ITERATIONS); do
        t=$( { time "/tmp/${bench}_base" > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]/ /g' | awk '{print $1*60+$2}' )
        base_total=$(echo "$base_total + $t" | bc)
    done
    base_mean=$(echo "scale=4; $base_total / $ITERATIONS" | bc)

    # Run instrumented iterations
    instr_total=0
    for i in $(seq 1 $ITERATIONS); do
        t=$( { time "/tmp/${bench}_instr" > /dev/null 2>&1; } 2>&1 | grep real | awk '{print $2}' | sed 's/[ms]/ /g' | awk '{print $1*60+$2}' )
        instr_total=$(echo "$instr_total + $t" | bc)
    done
    instr_mean=$(echo "scale=4; $instr_total / $ITERATIONS" | bc)

    # Compute overhead
    if [ "$(echo "$base_mean > 0" | bc)" -eq 1 ]; then
        overhead=$(echo "scale=2; (($instr_mean - $base_mean) / $base_mean) * 100" | bc)
    else
        overhead="N/A"
    fi

    echo "| ${bench} | ${base_mean} | ${instr_mean} | ${overhead} |"
done

echo ""
echo "================================================================"
echo " Benchmark suite completed."
echo "================================================================"

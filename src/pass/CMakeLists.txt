cmake_minimum_required(VERSION 3.20)

#===------------------------------------------------------------------------===#
# HLFIR Bounds Check Instrumentation Pass — CMakeLists.txt
#
# Integrates into the Flang optimizer library.
# Place this file at: flang/lib/Optimizer/Transforms/CMakeLists.txt (append)
#===------------------------------------------------------------------------===#

add_flang_library(FlangHLFIRBoundsCheck
  BoundsCheckInstrumentation.cpp

  DEPENDS
    FIRDialect
    HLFIROps
    MLIRArithDialect
    MLIRFuncDialect
    MLIRSCFDialect
    MLIRPass

  LINK_LIBS PUBLIC
    FIRDialect
    HLFIROps
    MLIRArithDialect
    MLIRFuncDialect
    MLIRSCFDialect
    MLIRPass
    MLIRTransforms
)

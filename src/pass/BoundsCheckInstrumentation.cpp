//===-- BoundsCheckInstrumentation.cpp - HLFIR Bounds Check Pass ----------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Flang HLFIR-Aware Array Bounds Sanitizer — Instrumentation Pass
//
// Department of Information Science and Engineering
// RV College of Engineering, Bengaluru — Academic Year 2025-26
//
// Team:
//   Vishwa Panchal  — 1RV23IS132
//   V Nikhil        — 1RV24IS413
//   Shreyas         — 1RV24IS410
//
// Implementation of the HLFIR bounds-check instrumentation pass.
//
// Algorithm overview
// ------------------
// For each function in the module the pass performs a single-pass walk of
// the operation list.  Whenever it encounters an hlfir.designate operation it:
//
//  (1) Resolves the defining SSA value back to its hlfir.declare origin.
//  (2) Extracts per-dimension lower-bound and extent SSA values from the
//      declare's shape/shapeShift operands.
//  (3) Computes the upper bound as  ub_d = lb_d + ext_d - 1  (in i64).
//  (4) For each dimension, inserts an arith.ori of two arith.cmpi
//      predicates (slt and sgt) to form the OOB condition.
//  (5) Wraps the call in an scf.if block that is only entered when the
//      condition is true, keeping the hot path branch-free.
//  (6) Extracts source location (file name + line number) from the MLIR
//      FileLineColLoc attribute attached to the designate op.
//  (7) Inserts a call to _FortranABoundsCheck with all required arguments.
//
// Supported Fortran array categories
// -----------------------------------
//   * Assumed-shape arrays       (FR-1)
//   * Array sections with stride (FR-2)
//   * Pointer-based arrays       (FR-3)
//   * Allocatable arrays         (FR-4)
//   * Negative / non-unity lower bounds (TC-07)
//   * Zero-size arrays           (TC-08)
//
//===----------------------------------------------------------------------===//

#include "flang/Optimizer/Transforms/BoundsCheckInstrumentation.h"

#include "flang/Optimizer/Dialect/FIROps.h"
#include "flang/Optimizer/HLFIR/HLFIROps.h"
#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinOps.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/IR/Diagnostics.h"
#include "mlir/IR/Location.h"
#include "mlir/IR/PatternMatch.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"
#include "llvm/ADT/SmallVector.h"
#include "llvm/ADT/StringRef.h"
#include "llvm/Support/raw_ostream.h"

#define DEBUG_TYPE "hlfir-bounds-check"

using namespace mlir;
using namespace hlfir;

namespace fir {

//===----------------------------------------------------------------------===//
// Helper utilities
//===----------------------------------------------------------------------===//

namespace {

/// Extract a FileLineColLoc from any MLIR location, returning nullopt when the
/// location does not carry file/line information (e.g. UnknownLoc).
static std::optional<FileLineColLoc>
extractFileLineCol(Location loc) {
  if (auto fileLoc = mlir::dyn_cast<FileLineColLoc>(loc))
    return fileLoc;
  if (auto fusedLoc = mlir::dyn_cast<FusedLoc>(loc))
    for (Location inner : fusedLoc.getLocations())
      if (auto fileLoc = mlir::dyn_cast<FileLineColLoc>(inner))
        return fileLoc;
  return std::nullopt;
}

/// Allocate and store a character string constant inline inside the function.
/// The alloca is placed in the function's entry block, while the string_lit
/// and store are placed at the current insertion point.
static Value createInlineStringAddress(OpBuilder &builder, func::FuncOp funcOp, Location loc, StringRef str) {
  auto strType = fir::CharacterType::get(builder.getContext(), 1, str.size());
  auto strAttr = builder.getStringAttr(str);
  auto sizeAttr = builder.getI64IntegerAttr(str.size());
  auto valTag = builder.getStringAttr(fir::StringLitOp::value());
  auto sizeTag = builder.getStringAttr(fir::StringLitOp::size());

  SmallVector<NamedAttribute> attrs = {
      NamedAttribute(valTag, strAttr),
      NamedAttribute(sizeTag, sizeAttr)};

  // 1. Allocate stack memory at the beginning of the function's entry block
  Value allocaVal;
  {
    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPointToStart(&funcOp.getBlocks().front());
    auto allocaOp = builder.create<fir::AllocaOp>(loc, strType);
    allocaVal = allocaOp.getResult();
  }

  // 2. Create the inline string literal and store it into the alloca at the instrumentation site
  auto stringLitOp = builder.create<fir::StringLitOp>(
      loc, ArrayRef<Type>{strType}, std::nullopt, attrs);
  builder.create<fir::StoreOp>(loc, stringLitOp.getResult(), allocaVal);
  
  return allocaVal;
}

} // anonymous namespace

//===----------------------------------------------------------------------===//
// HLFIRBoundsCheckPass — main pass implementation
//===----------------------------------------------------------------------===//

struct HLFIRBoundsCheckPass
    : public PassWrapper<HLFIRBoundsCheckPass, OperationPass<ModuleOp>> {

  MLIR_DEFINE_EXPLICIT_INTERNAL_INLINE_TYPE_ID(HLFIRBoundsCheckPass)

  StringRef getArgument() const final { return "hlfir-bounds-check"; }
  StringRef getDescription() const final {
    return "Insert runtime bounds-check calls around hlfir.designate ops";
  }

  //------------------------------------------------------------------------
  // Pass entry point
  //------------------------------------------------------------------------
  void runOnOperation() override {
    ModuleOp module = getOperation();
    OpBuilder builder(module.getContext());

    // Declare the external runtime function in the module symbol table.
    declareRuntimeFunction(builder, module);

    // Walk every function in the module.
    module.walk([&](func::FuncOp funcOp) {
      // Collect designate ops first to avoid mutating the IR while walking.
      SmallVector<hlfir::DesignateOp, 16> designateOps;
      funcOp.walk([&](hlfir::DesignateOp op) {
        designateOps.push_back(op);
      });

      for (auto designateOp : designateOps)
        instrumentDesignateOp(builder, module, funcOp, designateOp);
    });
  }

  //------------------------------------------------------------------------
  // Declare _FortranABoundsCheck in the module symbol table (once).
  //
  // Signature:
  //   void _FortranABoundsCheck(
  //       int64_t index,        // the accessed index value
  //       int64_t lowerBound,   // valid lower bound for this dimension
  //       int64_t upperBound,   // valid upper bound for this dimension
  //       int32_t dim,          // 1-based dimension number
  //       const char *varName,  // array variable name (NOT NUL-terminated)
  //       int64_t varNameLen,   // length of varName
  //       const char *fileName, // source file name (NOT NUL-terminated)
  //       int64_t fileNameLen,  // length of fileName
  //       int32_t lineNumber    // source line number
  //   );
  //------------------------------------------------------------------------
  void declareRuntimeFunction(OpBuilder &builder, ModuleOp module) {
    if (module.lookupSymbol<func::FuncOp>("_FortranABoundsCheck"))
      return;

    auto *ctx = module.getContext();
    auto i64Ty = builder.getI64Type();
    auto i32Ty = builder.getI32Type();
    auto charPtrTy = fir::ReferenceType::get(
        fir::CharacterType::get(ctx, 1, fir::CharacterType::unknownLen()));

    auto fnTy = builder.getFunctionType(
        {i64Ty, i64Ty, i64Ty, i32Ty, charPtrTy, i64Ty, charPtrTy, i64Ty, i32Ty}, {});

    OpBuilder::InsertionGuard guard(builder);
    builder.setInsertionPointToStart(module.getBody());
    auto fn = func::FuncOp::create(
        module.getLoc(), "_FortranABoundsCheck", fnTy);
    builder.insert(fn);
    fn.setPrivate();
  }

  //------------------------------------------------------------------------
  // Instrument a single hlfir.designate operation.
  //------------------------------------------------------------------------
  void instrumentDesignateOp(OpBuilder &builder, ModuleOp module,
                              func::FuncOp funcOp,
                              hlfir::DesignateOp designateOp) {
    auto loc = designateOp.getLoc();
    builder.setInsertionPoint(designateOp);

    // --- (0) Skip array sections (triplets) ---
    // If any dimension uses a triplet, this is a section creation, not an element access.
    // The actual element accesses will be caught later when elements are accessed from the section.
    for (bool b : designateOp.getIsTriplet()) {
      if (b) return;
    }

    // --- (1) Resolve hlfir.declare (for variable name) and determine if Boxed ---
    Value memref = designateOp.getMemref();
    bool isBox = memref.getType().isa<fir::BaseBoxType>();

    hlfir::DeclareOp declareOp;
    Value current = memref;
    while (current) {
      if (auto decl = current.getDefiningOp<hlfir::DeclareOp>()) {
        declareOp = decl;
        break;
      } else if (auto load = current.getDefiningOp<fir::LoadOp>()) {
        current = load.getMemref();
      } else if (auto convert = current.getDefiningOp<fir::ConvertOp>()) {
        current = convert.getValue();
      } else {
        break;
      }
    }

    // --- (2) Collect index operands from designate ---
    // DesignateOp carries indices for each accessed dimension.
    auto indices = designateOp.getIndices();
    if (indices.empty())
      return; // Scalar reference; nothing to check.

    // --- (3) Extract bounds from declare's shape operand or box ---
    Value shape;
    if (declareOp)
      shape = declareOp.getShape();

    // If a component shape is directly available (e.g. derived type arrays), use it
    if (Value compShape = designateOp.getComponentShape()) {
      shape = compShape;
    }

    // If the variable is neither a boxed type (descriptor) nor statically shaped,
    // we do not have enough bounds metadata to instrument it cleanly here.
    if (!isBox && !shape)
      return;

    int64_t rank = static_cast<int64_t>(indices.size());
    auto i64Ty  = builder.getI64Type();
    auto i32Ty  = builder.getI32Type();
    auto i1Ty   = builder.getI1Type();

    // --- (4) Build source-location string constants ---
    std::string fileName = "<unknown>";
    int32_t lineNumber   = 0;
    if (auto fileLineLoc = extractFileLineCol(loc)) {
      fileName   = fileLineLoc->getFilename().str();
      lineNumber = static_cast<int32_t>(fileLineLoc->getLine());
    }

    std::string varName = "<unnamed>";
    if (declareOp) {
      varName = declareOp.getUniqName().str();
      if (varName.empty())
        varName = "<unnamed>";
    }

    Value varPtr = createInlineStringAddress(builder, funcOp, loc, varName);
    Value filePtr = createInlineStringAddress(builder, funcOp, loc, fileName);

    // --- (5) For each dimension, insert OOB predicate + scf.if ---
    for (int64_t dim = 0; dim < rank; ++dim) {
      Value idx = indices[dim];

      // Ensure the index is an integer or index type before attempting conversion.
      if (!mlir::isa<mlir::IntegerType, mlir::IndexType>(idx.getType())) {
        continue;
      }

      // Cast index to i64.  IndexType requires IndexCastOp; IntegerType uses ExtSIOp.
      if (idx.getType() != i64Ty) {
        if (mlir::isa<mlir::IndexType>(idx.getType()))
          idx = builder.create<arith::IndexCastOp>(loc, i64Ty, idx);
        else
          idx = builder.create<arith::ExtSIOp>(loc, i64Ty, idx);
      }

      // Extract lower bound and extent for this dimension.
      // If the array is boxed, we can extract this dynamically from the descriptor.
      // Otherwise we fall back to statically known shapes from hlfir.declare.
      Value lowerBound, extent;

      if (isBox) {
        Value dimVal = builder.create<arith::ConstantIndexOp>(loc, dim);
        auto boxDims = builder.create<fir::BoxDimsOp>(
            loc, builder.getIndexType(), builder.getIndexType(),
            builder.getIndexType(), memref, dimVal);
        lowerBound = boxDims.getResult(0);
        extent     = boxDims.getResult(1);
      } else {
        auto shapeShiftOp = shape.getDefiningOp<fir::ShapeShiftOp>();
        auto shapeOp      = shape.getDefiningOp<fir::ShapeOp>();

        if (shapeShiftOp) {
          auto operands = shapeShiftOp.getOperands();
          // DEFENSIVE QA: Ensure operands are valid and within array bounds
          if (static_cast<size_t>(dim * 2 + 1) >= operands.size()) continue;
          lowerBound = operands[dim * 2];
          extent     = operands[dim * 2 + 1];
        } else if (shapeOp) {
          auto operands = shapeOp.getOperands();
          if (static_cast<size_t>(dim) >= operands.size()) continue;
          // Lower bound is implicitly 1 per Fortran default.
          lowerBound = builder.create<arith::ConstantIntOp>(loc, 1, i64Ty);
          extent = operands[dim];
        } else {
          // Cannot statically resolve dynamic descriptor shape here.
          // Safely skip bounds check for this dimension to avoid false positives.
          continue;
        }
      }

      // Ensure bounds and extents are numeric types before conversion.
      if (!mlir::isa<mlir::IntegerType, mlir::IndexType>(lowerBound.getType()) ||
          !mlir::isa<mlir::IntegerType, mlir::IndexType>(extent.getType())) {
        continue;
      }

      // Cast operands to i64.  IndexType → IndexCastOp; IntegerType → ExtSIOp.
      if (lowerBound.getType() != i64Ty) {
        if (mlir::isa<mlir::IndexType>(lowerBound.getType()))
          lowerBound = builder.create<arith::IndexCastOp>(loc, i64Ty, lowerBound);
        else
          lowerBound = builder.create<arith::ExtSIOp>(loc, i64Ty, lowerBound);
      }
      if (extent.getType() != i64Ty) {
        if (mlir::isa<mlir::IndexType>(extent.getType()))
          extent = builder.create<arith::IndexCastOp>(loc, i64Ty, extent);
        else
          extent = builder.create<arith::ExtSIOp>(loc, i64Ty, extent);
      }

      // upperBound = lowerBound + extent - 1
      Value one       = builder.create<arith::ConstantIntOp>(loc, 1, i64Ty);
      Value extentMinusOne = builder.create<arith::SubIOp>(loc, extent, one);
      Value upperBound = builder.create<arith::AddIOp>(loc, lowerBound, extentMinusOne);

      // Check for assumed-size arrays where extent < 0 (unknown upper bound)
      Value zero      = builder.create<arith::ConstantIntOp>(loc, 0, i64Ty);
      Value isAssumedSize = builder.create<arith::CmpIOp>(loc, arith::CmpIPredicate::slt, extent, zero);

      // OOB condition: idx < lowerBound || idx > upperBound
      Value tooLow  = builder.create<arith::CmpIOp>(
          loc, arith::CmpIPredicate::slt, idx, lowerBound);
      Value tooHigh = builder.create<arith::CmpIOp>(
          loc, arith::CmpIPredicate::sgt, idx, upperBound);

      // If assumed-size, ignore upper bound violations for this dimension
      Value falseVal = builder.create<arith::ConstantIntOp>(loc, 0, i1Ty);
      tooHigh = builder.create<arith::SelectOp>(loc, isAssumedSize, falseVal, tooHigh);

      Value dimOOB  = builder.create<arith::OrIOp>(loc, tooLow, tooHigh);

      // --- (6) Insert scf.if wrapping the runtime call ---
      Value dimVal = builder.create<arith::ConstantIntOp>(loc, dim + 1, i32Ty);
      Value lineVal =
          builder.create<arith::ConstantIntOp>(loc, lineNumber, i32Ty);

      // Using varPtr and filePtr allocated inline before the loop.

      // Cast string pointers to the opaque char* the runtime expects.
      auto charPtrTy = fir::ReferenceType::get(
          fir::CharacterType::get(builder.getContext(), 1,
                                  fir::CharacterType::unknownLen()));
      Value varPtrCast  = builder.create<fir::ConvertOp>(loc, charPtrTy, varPtr);
      Value filePtrCast = builder.create<fir::ConvertOp>(loc, charPtrTy, filePtr);

      // String lengths as i64 constants.
      Value varNameLenVal =
          builder.create<arith::ConstantIntOp>(loc, varName.size(), i64Ty);
      Value fileNameLenVal =
          builder.create<arith::ConstantIntOp>(loc, fileName.size(), i64Ty);

      builder.create<scf::IfOp>(loc, dimOOB,
          [&](OpBuilder &ifBuilder, Location ifLoc) {
            ifBuilder.create<func::CallOp>(
                ifLoc, "_FortranABoundsCheck",
                TypeRange{},
                ValueRange{idx, lowerBound, upperBound, dimVal,
                           varPtrCast, varNameLenVal,
                           filePtrCast, fileNameLenVal, lineVal});
            ifBuilder.create<scf::YieldOp>(ifLoc);
          });
    } // end for each dimension
  }   // end instrumentDesignateOp
};    // end HLFIRBoundsCheckPass

//===----------------------------------------------------------------------===//
// Pass creation entry point
//===----------------------------------------------------------------------===//

std::unique_ptr<mlir::Pass> createHLFIRBoundsCheckPass() {
  return std::make_unique<HLFIRBoundsCheckPass>();
}

} // namespace fir

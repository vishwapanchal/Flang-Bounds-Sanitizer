# syntax=docker/dockerfile:1
# ==========================================================================
# Flang HLFIR Bounds Sanitizer — Docker Build Environment
#
# Optimized for systems with 8GB RAM.  Uses conservative parallelism
# (-j 2 compile, 1 link job) and MinSizeRel build type to minimize
# peak memory consumption during the LLVM/Flang compilation.
#
# Build:   DOCKER_BUILDKIT=1 docker build -t flang-bounds-sanitizer .
# Run:     docker run --rm flang-bounds-sanitizer
# ==========================================================================
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

# Install build toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake ninja-build build-essential clang lld git python3 ccache bc \
    && rm -rf /var/lib/apt/lists/*

# Create swap space for safety on low-memory hosts
RUN fallocate -l 4G /swapfile && chmod 600 /swapfile \
    && mkswap /swapfile && echo '/swapfile none swap sw 0 0' >> /etc/fstab

WORKDIR /workspace

# Shallow-clone LLVM stable release 19.1.7 to minimize download time, disk usage, and guarantee consistency
RUN git clone -b llvmorg-19.1.7 --depth 1 https://github.com/llvm/llvm-project.git

# Copy project source files into the container
COPY src/ /workspace/src/

# Inject the bounds sanitizer pass and runtime into the LLVM tree
RUN set -eux && \
    echo "==> Injecting instrumentation pass..." && \
    cp /workspace/src/pass/BoundsCheckInstrumentation.cpp \
       /workspace/llvm-project/flang/lib/Optimizer/Transforms/ && \
    cp /workspace/src/pass/BoundsCheckInstrumentation.h \
       /workspace/llvm-project/flang/include/flang/Optimizer/Transforms/ && \
    sed -i '/add_flang_library(FIRTransforms/a\  BoundsCheckInstrumentation.cpp' \
       /workspace/llvm-project/flang/lib/Optimizer/Transforms/CMakeLists.txt && \
    \
    echo "==> Injecting runtime library..." && \
    RUNTIME_DIR=$(find /workspace/llvm-project -type d \
        \( -path "*/flang-rt/lib/runtime" -o -path "*/flang/runtime" \) \
        | head -n 1) && \
    cp /workspace/src/runtime/bounds-check.cpp "$RUNTIME_DIR/" && \
    cp /workspace/src/runtime/bounds-check.h   "$RUNTIME_DIR/" && \
    if echo "$RUNTIME_DIR" | grep -q "flang-rt"; then \
        sed -i '/add_flangrt_library(flang_rt.runtime/a\  bounds-check.cpp' \
            "$RUNTIME_DIR/CMakeLists.txt"; \
    else \
        sed -i '/add_flang_library(FortranRuntime/a\  bounds-check.cpp' \
            "$RUNTIME_DIR/CMakeLists.txt"; \
    fi && \
    \
    echo "==> Patching pipeline..." && \
    sed -i '1s/^/#include "flang\/Optimizer\/Transforms\/BoundsCheckInstrumentation.h"\n/' \
        /workspace/llvm-project/flang/include/flang/Tools/CLOptions.inc && \
    sed -i '/pm.addPass(hlfir::createLowerHLFIRIntrinsics());/i\  pm.addPass(fir::createHLFIRBoundsCheckPass());' \
        /workspace/llvm-project/flang/include/flang/Tools/CLOptions.inc

WORKDIR /workspace/llvm-project/build

ENV CCACHE_DIR=/ccache

# CMake configuration — optimized for 8GB RAM systems
RUN cmake -G Ninja ../llvm \
    -DCMAKE_BUILD_TYPE=MinSizeRel \
    -DLLVM_ENABLE_PROJECTS="clang;flang;mlir" \
    -DLLVM_TARGETS_TO_BUILD="host" \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DLLVM_USE_LINKER=lld \
    -DBUILD_SHARED_LIBS=ON \
    -DLLVM_ENABLE_ASSERTIONS=OFF \
    -DLLVM_BUILD_TESTS=OFF \
    -DLLVM_BUILD_EXAMPLES=OFF \
    -DLLVM_BUILD_DOCS=OFF \
    -DLLVM_ENABLE_BINDINGS=OFF \
    -DLLVM_PARALLEL_LINK_JOBS=1

# Build with conservative parallelism.  BuildKit cache mount preserves
# ccache state across builds for fast incremental recompilation.
RUN --mount=type=cache,target=/ccache \
    swapon /swapfile 2>/dev/null || true && \
    ccache -M 10G && \
    ninja -j 2 flang-new

# Default command: compile and run the demo program
CMD set -e && \
    echo "" && \
    echo "==========================================================" && \
    echo " FLANG COMPILER READY — RUNNING BOUNDS SANITIZER DEMO" && \
    echo "==========================================================" && \
    cd /workspace && \
    ./llvm-project/build/bin/flang-new -O2 -fcheck=bounds \
        src/demo/demo.f90 -o demo_run && \
    ./demo_run

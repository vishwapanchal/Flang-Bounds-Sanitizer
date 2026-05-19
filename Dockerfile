# syntax=docker/dockerfile:1
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake ninja-build build-essential clang lld git python3 ccache \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
# Clone LLVM shallowly to save massive amounts of time and space
RUN git clone --depth 1 https://github.com/llvm/llvm-project.git

COPY src/ /workspace/src/

RUN echo "==> Injecting Bounds Sanitizer into LLVM..." && \
    cp /workspace/src/pass/BoundsCheckInstrumentation.cpp /workspace/llvm-project/flang/lib/Optimizer/Transforms/ && \
    cp /workspace/src/pass/BoundsCheckInstrumentation.h /workspace/llvm-project/flang/include/flang/Optimizer/Transforms/ && \
    sed -i '/add_flang_library(FIRTransforms/a\  BoundsCheckInstrumentation.cpp' /workspace/llvm-project/flang/lib/Optimizer/Transforms/CMakeLists.txt && \
    RUNTIME_DIR=$(find /workspace/llvm-project -type d \( -path "*/flang-rt/lib/runtime" -o -path "*/flang/runtime" \) | head -n 1) && \
    cp /workspace/src/runtime/bounds-check.cpp "$RUNTIME_DIR/" && \
    cp /workspace/src/runtime/bounds-check.h "$RUNTIME_DIR/" && \
    if echo "$RUNTIME_DIR" | grep -q "flang-rt"; then \
        sed -i '/add_flangrt_library(flang_rt.runtime/a\  bounds-check.cpp' "$RUNTIME_DIR/CMakeLists.txt"; \
    else \
        sed -i '/add_flang_library(FlangRuntime/a\  bounds-check.cpp' "$RUNTIME_DIR/CMakeLists.txt"; \
    fi && \
    sed -i '/pm.addPass(hlfir::createLowerHLFIRIntrinsics());/i\  pm.addPass(fir::createHLFIRBoundsCheckPass());' /workspace/llvm-project/flang/lib/Optimizer/Passes/Pipelines.cpp

WORKDIR /workspace/llvm-project/build

# Configure ccache directory
ENV CCACHE_DIR=/ccache

# Highly optimized CMake configuration to minimize build time
RUN cmake -G Ninja ../llvm \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_PROJECTS="flang;mlir" \
    -DLLVM_ENABLE_RUNTIMES="flang-rt" \
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
    -DLLVM_PARALLEL_LINK_JOBS=2

# Use Docker BuildKit Cache Mount to save progress externally!
# With 12 cores, we use -j 12. 16GB RAM is well-handled by restricting link jobs to 2.
RUN --mount=type=cache,target=/ccache \
    ccache -M 10G && \
    ninja -j 12 flang

CMD echo -e "\n==========================================================" && \
    echo " FLANG COMPILER READY! RUNNING BOUNDS SANITIZER DEMO... " && \
    echo "==========================================================" && \
    cd /workspace && \
    ./llvm-project/build/bin/flang-new -O2 -fcheck=bounds src/demo/demo.f90 -o demo_run && \
    ./demo_run

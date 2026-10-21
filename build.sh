#!/data/data/com.termux/files/usr/bin/bash
# Build llama.cpp with Vulkan GPU backend on Termux (Android).
# Tested on aarch64, Adreno GPU. Re-run safe: clone and patch are skipped if present.
set -euo pipefail

LLAMA_DIR="${LLAMA_DIR:-$HOME/llama.cpp}"
JOBS="${JOBS:-4}"
PATCH="$(cd "$(dirname "$0")" && pwd)/patches/android-aligned-alloc.patch"

echo "==> [1/5] install dependencies"
DEBIAN_FRONTEND=noninteractive pkg install -y \
    git cmake clang ninja make \
    vulkan-headers vulkan-loader glslang shaderc \
    spirv-headers spirv-tools

echo "==> [2/5] clone llama.cpp -> $LLAMA_DIR"
if [ -d "$LLAMA_DIR/.git" ]; then
    echo "    reuse existing $LLAMA_DIR"
else
    git clone --depth 1 https://github.com/ggml-org/llama.cpp.git "$LLAMA_DIR"
fi

echo "==> [3/5] apply Android patch (aligned_alloc needs API 29, Termux targets 24)"
if patch -d "$LLAMA_DIR" -p1 --forward --dry-run < "$PATCH" >/dev/null 2>&1; then
    patch -d "$LLAMA_DIR" -p1 --forward < "$PATCH"
else
    echo "    already applied or source drifted; if build fails, check ggml/src/ggml-vulkan/ggml-vulkan-buffers.cpp"
fi

echo "==> [4/5] configure + build (GGML_VULKAN=ON, -j$JOBS; raise JOBS if you have RAM)"
cmake -S "$LLAMA_DIR" -B "$LLAMA_DIR/build" -G Ninja \
    -DGGML_VULKAN=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CURL=OFF
cmake --build "$LLAMA_DIR/build" -j "$JOBS"

echo "==> [5/5] switch to Android system Vulkan loader (uses real GPU, not lavapipe)"
DEBIAN_FRONTEND=noninteractive pkg uninstall -y vulkan-loader-generic 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive pkg install -y vulkan-loader-android

echo "==> Vulkan devices:"
"$LLAMA_DIR/build/bin/llama-cli" --list-devices || true

echo
echo "done. binaries: $LLAMA_DIR/build/bin"
echo "example: $LLAMA_DIR/build/bin/llama-cli -m model.gguf -ngl 99"

# llama.cpp-termux-vulkan

一键在 Termux (Android, aarch64) 上编译带 **Vulkan GPU 后端**的 llama.cpp。

实测：Adreno (TM) 735，`llama-cli --list-devices` 可列出 `Vulkan0`。

## 用法

```bash
git clone https://github.com/plmzaq2112/llama.cpp-termux-vulkan.git
cd llama.cpp-termux-vulkan
bash build.sh
```

产物在 `~/llama.cpp/build/bin/`（可用环境变量 `LLAMA_DIR` 改位置）：

```bash
~/llama.cpp/build/bin/llama-cli --list-devices          # 确认 GPU 出现
~/llama.cpp/build/bin/llama-cli -m model.gguf -ngl 99   # 全量卸载到 GPU 跑
~/llama.cpp/build/bin/llama-server -m model.gguf -ngl 99 --host 0.0.0.0 -p 8080
```

默认 `JOBS=4`。编译并行度太高容易被 Android LMK 杀掉；内存大的机器可以 `JOBS=8 bash build.sh` 加速。

## 脚本做了什么

1. `pkg install` 构建依赖：git、cmake、clang、ninja、vulkan-headers、glslang、shaderc、spirv-headers 等。
2. 浅克隆 [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) 到 `~/llama.cpp`（已存在则复用）。
3. 应用 `patches/android-aligned-alloc.patch`。
4. `cmake -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release` + ninja 编译。
5. 把 `vulkan-loader-generic` 换成 `vulkan-loader-android`（链接到系统 `/system/lib64/libvulkan.so`，才能用手机真实 GPU；默认的 generic loader 只带 Mesa 软渲染，检测不到 Adreno/Mali）。

## 补丁说明

`patches/android-aligned-alloc.patch`：Vulkan 后端的 `portable_aligned_malloc` 用了 `std::aligned_alloc`，但 Bionic 从 API 29 才提供它，Termux 的 clang 目标是 API 24，会编译报错。补丁在 `__ANDROID__` 下改用 `posix_memalign`（API 16+ 可用），`free()` 行为不变。

llama.cpp 若更新导致补丁冲突，需手动改 `ggml/src/ggml-vulkan/ggml-vulkan-buffers.cpp` 里的 `portable_aligned_malloc`，或等上游修复后删掉补丁步骤。

## 常见问题

- **`Available devices: (none)`**：loader 不对，执行 `pkg uninstall vulkan-loader-generic; pkg install vulkan-loader-android`。
- **编译到一半进程消失**：被系统 LMK 杀了，`JOBS=2 bash build.sh` 重跑，ninja 会续编。
- **`Could not find package configuration file provided by "SPIRV-Headers"`**：漏装 `spirv-headers`，重跑脚本即可。

# Stage 1: Builder (installe deps et compile avec tes flags opti)
FROM ubuntu:24.04 AS builder

# Installe dépendances (basé sur README ik_llama.cpp et tes needs : Clang, OpenMP, etc.)
RUN apt-get update && apt-get install -y \
    git cmake build-essential libomp-dev clang lld ccache \
    && rm -rf /var/lib/apt/lists/*

# Clone le repo (sera sync via CI, mais clone initial ici)
RUN git clone https://github.com/ikawrakow/ik_llama.cpp /ik_llama.cpp

# Build avec tes flags ultra-opti CPU-only pour Ryzen 7 8745HS (Zen 4)
WORKDIR /ik_llama.cpp/build
RUN cmake .. -DCMAKE_BUILD_TYPE=Release \
    -DGGML_AVX2=ON -DGGML_F16C=ON -DGGML_FMA=ON -DGGML_NATIVE=ON \
    -DGGML_VULKAN=OFF -DGGML_CCACHE=ON -DGGML_OPENMP=ON \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-march=znver4 -mtune=znver4 -O3 -fno-finite-math-only -mavx512f -mavx512vl -mavx512bw -mavx512dq -fopenmp -fuse-ld=lld" \
    -DCMAKE_CXX_FLAGS="-march=znver4 -mtune=znver4 -O3 -fno-finite-math-only -mavx512f -mavx512vl -mavx512bw -mavx512dq -fopenmp -fuse-ld=lld" \
    && make -j$(nproc)

# Stage 2: Runtime (image légère, copie binaires et focus server)
FROM ubuntu:24.04

# Copie les binaires compilés (ex. llama-server, llama-cli, etc.)
COPY --from=builder /ik_llama.cpp/build/bin /usr/local/bin

# Deps runtime minimales (pour run sur CPU)
RUN apt-get update && apt-get install -y libomp-dev && rm -rf /var/lib/apt/lists/*

# Expose port pour server (comme dans ton Dockerfile original)
EXPOSE 8080

# Entrypoint pour llama-server avec params opti par défaut (ajuste pour ton usage : IQ4_XS, SER, etc.)
ENTRYPOINT ["/usr/local/bin/llama-server"]
CMD ["--model", "/models/model.gguf", "--ctx-size", "32768", "-t", "12", "-ser", "6,1", "--no-mmap", "--cache-type-k", "f16", "--cache-type-v", "f16"]

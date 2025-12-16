// fft_filter_soft_kernels.cu

#include "core/fft_filter_soft_kernels.cuh"
#include <cuda_runtime.h>
#include <cufft.h>
#include <vector>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <cfloat>

#ifdef __INTELLISENSE__
#define __global__
#define __device__
#define __host__
inline void __syncthreads() {}
dim3 blockIdx, blockDim, threadIdx, gridDim;
#endif

__global__ void input_to_complex(const uint8_t* __restrict__ src,
    cufftComplex* __restrict__ dst,
    int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        dst[i].x = static_cast<float>(src[i]);
        dst[i].y = 0.0f;
    }
}

__global__ void fftshift2D(const cufftComplex* __restrict__ src,
    cufftComplex* __restrict__ dst,
    int width, int height) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int N = width * height;
    if (i >= N) return;
    int x = i % width;
    int y = i / width;
    int nx = (x + width / 2) % width;
    int ny = (y + height / 2) % height;
    int j = ny * width + nx;
    dst[j] = src[i];
}

__global__ void compute_magnitude(const cufftComplex* __restrict__ src,
    float* __restrict__ mag,
    int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        float re = src[i].x;
        float im = src[i].y;
        mag[i] = sqrtf(re * re + im * im);
    }
}

__global__ void apply_mask(const cufftComplex* __restrict__ fshift,
    const float* __restrict__ mag,
    float thr,
    cufftComplex* __restrict__ high_freq,
    cufftComplex* __restrict__ low_freq,
    int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        if (mag[i] > thr) {
            high_freq[i] = fshift[i];
            low_freq[i].x = 0.0f; low_freq[i].y = 0.0f;
        }
        else {
            low_freq[i] = fshift[i];
            high_freq[i].x = 0.0f; high_freq[i].y = 0.0f;
        }
    }
}

__global__ void compute_spectrum_from_mag(const float* __restrict__ mag,
    uint8_t* __restrict__ out_u8,
    int N, float minlog, float maxlog) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        float v = log1pf(mag[i]);
        float t = (v - minlog) / (maxlog - minlog + 1e-12f);
        t = fminf(1.f, fmaxf(0.f, t));
        out_u8[i] = static_cast<uint8_t>(t * 255.f + 0.5f);
    }
}

__global__ void compute_recon_magnitude(const cufftComplex* __restrict__ src,
    float* __restrict__ mag,
    int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        float re = src[i].x;
        float im = src[i].y;
        mag[i] = sqrtf(re * re + im * im);
    }
}

__global__ void reconstruction_from_mag(const float* __restrict__ mag,
    uint8_t* __restrict__ out_u8,
    int N, float minv, float maxv) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        float t = (mag[i] - minv) / (maxv - minv + 1e-12f);
        t = fminf(1.f, fmaxf(0.f, t));
        out_u8[i] = static_cast<uint8_t>(t * 255.f + 0.5f);
    }
}

// block 級縮減：取最小值
__global__ void reduce_min(const float* __restrict__ in,
    float* __restrict__ out,
    int N) {
    extern __shared__ float s[];
    int tid = threadIdx.x;
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    float v = FLT_MAX;
    if (i < N) v = in[i];
    s[tid] = v;
    __syncthreads();

    // 標準二分縮減
    for (int stride = blockDim.x >> 1; stride > 0; stride >>= 1) {
        if (tid < stride) s[tid] = fminf(s[tid], s[tid + stride]);
        __syncthreads();
    }
    if (tid == 0) out[blockIdx.x] = s[0];
}

// block 級縮減：取最大值
__global__ void reduce_max(const float* __restrict__ in,
    float* __restrict__ out,
    int N) {
    extern __shared__ float s[];
    int tid = threadIdx.x;
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    float v = -FLT_MAX;
    if (i < N) v = in[i];
    s[tid] = v;
    __syncthreads();

    for (int stride = blockDim.x >> 1; stride > 0; stride >>= 1) {
        if (tid < stride) s[tid] = fmaxf(s[tid], s[tid + stride]);
        __syncthreads();
    }
    if (tid == 0) out[blockIdx.x] = s[0];
}

__global__ void binarize_u8(const uint8_t* __restrict__ src,
    uint8_t* __restrict__ dst,
    int N, uint8_t thr) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) dst[i] = (src[i] > thr) ? 255 : 0;
}

__global__ void overlay_gray_with_red_mask(const uint8_t* __restrict__ gray,
    const uint8_t* __restrict__ mask_bw,
    uint8_t* __restrict__ out_rgb,
    int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;

    float g = static_cast<float>(gray[i]);
    uint8_t m = mask_bw[i];

    if (m == 255) {
        // 0.6 * gray + 0.4 * red(255,0,0)
        float r = 0.6f * g + 0.4f * 255.0f;
        float gb = 0.6f * g;
        r = r > 255.f ? 255.f : r;
        gb = gb > 255.f ? 255.f : gb;

        out_rgb[3 * i + 0] = static_cast<uint8_t>(r);
        out_rgb[3 * i + 1] = static_cast<uint8_t>(gb);
        out_rgb[3 * i + 2] = static_cast<uint8_t>(gb);
    }
    else {
        uint8_t v = static_cast<uint8_t>(g);
        out_rgb[3 * i + 0] = v;
        out_rgb[3 * i + 1] = v;
        out_rgb[3 * i + 2] = v;
    }
}


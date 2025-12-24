// fft_filter_soft_kernels.cuh

#pragma once
#include <cuda_runtime.h>
#include <cufft.h>
#include <vector>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <cfloat>


__global__ void input_to_complex(const uint8_t* __restrict__ src,
    cufftComplex* __restrict__ dst,
    int N);

__global__ void fftshift2D(const cufftComplex* __restrict__ src,
    cufftComplex* __restrict__ dst,
    int width, int height) ;

__global__ void compute_magnitude(const cufftComplex* __restrict__ src,
    float* __restrict__ mag,
    int N);

__global__ void apply_mask(const cufftComplex* __restrict__ fshift,
    const float* __restrict__ mag,
    float thr,
    cufftComplex* __restrict__ high_freq,
    cufftComplex* __restrict__ low_freq,
    int N);

__global__ void compute_spectrum_from_mag(const float* __restrict__ mag,
    uint8_t* __restrict__ out_u8,
    int N, float minlog, float maxlog);

__global__ void compute_recon_magnitude(const cufftComplex* __restrict__ src,
    float* __restrict__ mag,
    int N);

__global__ void reconstruction_from_mag(const float* __restrict__ mag,
    uint8_t* __restrict__ out_u8,
    int N, float minv, float maxv);

// block 級縮減：取最小值
__global__ void reduce_min(const float* __restrict__ in,
    float* __restrict__ out,
    int N);

// block 級縮減：取最大值
__global__ void reduce_max(const float* __restrict__ in,
    float* __restrict__ out,
    int N);


__global__ void binarize_u8(const uint8_t* __restrict__ src,
    uint8_t* __restrict__ dst,
    int N, uint8_t thr);

__global__ void overlay_gray_with_red_mask(const uint8_t* __restrict__ gray,
    const uint8_t* __restrict__ mask_bw,
    uint8_t* __restrict__ out_rgb,
    int N);


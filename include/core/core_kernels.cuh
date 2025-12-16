// core_kernels.cuh
#pragma once
#include <cuda_runtime.h>
#include <cstdint>

namespace core {
    // 1D 運算：傳入 N (W*H)
    __global__ void k_brighten_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, int bright);
    __global__ void k_threshold_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, uint8_t thresh);
    __global__ void k_invert_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N);

    // 2D 運算：維持 W, H
    __global__ void k_zeroBorder_u8(uint8_t* __restrict__ in, int roiW, int roiH, int t);
    __global__ void k_convolution_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int maskSize);


    // [新增] 1D 行統計運算 (適合 Mura 檢測)
    __global__ void k_calcColumnBackground_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ background, int W, int H, float sigmaFactor);

    // [新增] 擴展背景 (1D -> 2D)
    __global__ void k_expandBackground_u8(const uint8_t* __restrict__ bg_in, uint8_t* __restrict__ img_out, int W, int H);

    // [新增] 背景扣除 (In - Bg + 127)
    __global__ void k_subtractBackground_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H);

}
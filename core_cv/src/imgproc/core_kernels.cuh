// AOI_SDK\core_cv\src\imgproc\core_kernels.cuh
#pragma once
#include <cuda_runtime.h>
#include <cstdint>

namespace core {
    //  亮度 (1D)
    __global__ void k_brighten_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, int bright);
    
    // 二值化 (1D)
    __global__ void k_threshold_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, uint8_t thresh);
    
    // 反轉 (1D)
    __global__ void k_invert_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N);
    
    // 邊框 (維持 2D)
    __global__ void k_zeroBorder_u8(uint8_t* __restrict__ in, int roiW, int roiH, int t);
    
    // Float 轉 Uint8(單純截斷，不正規化)
    __global__ void k_f32_to_u8_clamp(const float* __restrict__ in, uint8_t* __restrict__ out, int N);

    // 卷積 (維持 2D)
    __global__ void k_convolution_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int maskSize);
    
    // Float 版本的卷積 (用於高斯模糊)
    __global__ void k_convolution_f32(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int maskSize);

    // Pass 1: 水平卷積 (Row)
    __global__ void k_gaussianBlurRow(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int ksize);
    
    // Pass 2: 垂直卷積 (Column)
    __global__ void k_gaussianBlurCol(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int ksize);
    
    // 計算 Column 背景 (含 Sigma Clipping 離群值剔除)
    __global__ void k_calcColumnBackground_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ background, int W, int H, float sigmaFactor);
    
    // 擴展背景
    __global__ void k_expandBackground_u8(const uint8_t* __restrict__ bg_in, uint8_t* __restrict__ img_out, int W, int H);
    
    // 減去背景+127
    __global__ void k_subtractBackgroundShift_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H);
    
    // 減去背景絕對值
	__global__ void k_subtractBackgroundAbs_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H);

    // 定義 Ridge 偵測模式
    enum class RidgeMode {
        VERTICAL = 0,
        HORIZONTAL = 1,
        BOTH = 2
    };

    //  Sobel 邊緣強度 (Magnitude)
    __global__ void k_sobelMagnitude_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int W, int H);

    // 計算 Hessian 響應 (需輸入 float 影像，通常是高斯模糊後的)
    __global__ void k_hessianResponse(const float* __restrict__ in, float* __restrict__ out, int W, int H, RidgeMode mode);

    // MinMax 正規化 (將 float 轉回 uint8)
    __global__ void k_normalizeMinMax_f32_u8(const float* __restrict__ in, uint8_t* __restrict__ out, int N, float minVal, float maxVal);

    // 輔助: uint8 轉 float
    __global__ void k_u8_to_f32(const uint8_t* __restrict__ in, float* __restrict__ out, int N);

}
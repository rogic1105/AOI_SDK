// AOI_SDK\core_cv\include\core_cv\imgproc\core_background.hpp

#pragma once
#include <cstdint>
#include <cuda_runtime.h>

namespace core {
    // 1D Column 統計背景
    void calcColumnBackground_u8_gpu(const uint8_t* d_in, uint8_t* d_bg_out, int W, int H, float sigmaFactor, cudaStream_t s = 0);

    // 背景擴展 (將 1D 或小圖擴展為全尺寸背景)
    void expandBackground_u8_gpu(const uint8_t* d_bg_in, uint8_t* d_img_out, int W, int H, cudaStream_t s = 0);

    // 背景去除運算
    void subtractBackgroundShift_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
    void subtractBackgroundAbs_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
}
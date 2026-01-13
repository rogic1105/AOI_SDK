// AOI_SDK\core_cv\include\core_cv\imgproc\core_features.hpp

#pragma once
#include <cstdint>
#include <cuda_runtime.h>

namespace core {
    // 定義 Ridge Mode (公開給使用者看)
    enum class RidgeMode {
        VERTICAL = 0,
        HORIZONTAL = 1,
        BOTH = 2
    };

    void sobel_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
    void hessianRidge_u8_gpu(
        const uint8_t* d_in,
        uint8_t* d_out,
        int W, int H,
        float sigma,
        const char* mode_str,
        cudaStream_t s,
        uint8_t* d_temp_blur_u8,
        float* d_temp_blur_f32,
        float* d_temp_response,
        void* d_workspace = nullptr // [新增] 接收外部 workspace
    );

}
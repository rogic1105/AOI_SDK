// AOI_SDK\core_cv\src\imgproc\features\features_ops.cu

#include "core_cv/base/cuda_utils.hpp"
#include "features_kernels.cuh"

#include "core_cv/imgproc/core_filters.hpp"
#include "core_cv/imgproc/core_utils.hpp"

namespace core {

    void sobel_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s) {
        dim3 grid, block;
        get_optimal_launch_2d(k_sobelMagnitude_u8, W, H, grid, block);
        k_sobelMagnitude_u8 << <grid, block, 0, s >> > (d_in, d_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

    void hessianRidge_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, const char* mode_str, cudaStream_t s) {
        int num_pixels = W * H;
        int gridSize, blockSize;

        // 1. 解析模式
        RidgeMode mode = RidgeMode::VERTICAL;
        if (strcmp(mode_str, "horizontal") == 0) mode = RidgeMode::HORIZONTAL;
        else if (strcmp(mode_str, "both") == 0) mode = RidgeMode::BOTH;

        // 2. 記憶體分配
        // d_blur_u8:  存放高斯模糊後的結果 (Uint8)
        // d_blur_f32: Hessian Kernel 需要 Float 輸入
        // d_response: Hessian 計算結果
        uint8_t* d_blur_u8 = nullptr;
        float* d_blur_f32 = nullptr;
        float* d_response = nullptr;

        CUDA_CHECK(cudaMalloc(&d_blur_u8, num_pixels * sizeof(uint8_t)));
        CUDA_CHECK(cudaMalloc(&d_blur_f32, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_response, num_pixels * sizeof(float)));

        // 3. 執行 Gaussian Blur (呼叫 Filters 模組)
        // 自動計算 ksize: 6 * sigma + 1
        int ksize = (int)(6.0f * sigma + 1.0f);
        if (ksize % 2 == 0) ksize++;

        core::gaussianBlur_u8_gpu(d_in, d_blur_u8, W, H, sigma, ksize, s);

        // 4. 轉 Float (呼叫 Utils 模組)
        // 因為 Hessian 微分對數值敏感，需轉回 Float 計算
        core::convert_u8_to_f32_gpu(d_blur_u8, d_blur_f32, num_pixels, s);

        // 5. 計算 Hessian Response (本模組的核心邏輯)
        get_optimal_launch_1d(k_hessianResponse, num_pixels, gridSize, blockSize);
        k_hessianResponse << <gridSize, blockSize, 0, s >> > (d_blur_f32, d_response, W, H, mode);

        // 6. 正規化 MinMax 並轉回 Uint8 (呼叫 Utils 模組)
        // 這取代了原本手寫的 Thrust MinMax 和 Normalize Kernel
        core::normalize_minmax_f32_u8_gpu(d_response, d_out, num_pixels, s);

        // 7. 清理
        CUDA_CHECK(cudaFree(d_blur_u8));
        CUDA_CHECK(cudaFree(d_blur_f32));
        CUDA_CHECK(cudaFree(d_response));
    }

}
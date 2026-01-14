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
        void* d_workspace // [新增] 接收參數
    ) {
        int num_pixels = W * H;
        int gridSize, blockSize;

        detectionMode mode = detectionMode::VERTICAL;
        if (strcmp(mode_str, "horizontal") == 0) mode = detectionMode::HORIZONTAL;
        else if (strcmp(mode_str, "both") == 0) mode = detectionMode::BOTH;

        int ksize = (int)(6.0f * sigma + 1.0f);
        if (ksize % 2 == 0) ksize++;

        // [關鍵修改] 將 d_workspace 傳進去！
        // 這樣 gaussianBlur 就會使用預分配好的記憶體，不再 cudaMalloc
        core::gaussianBlur_u8_gpu(d_in, d_temp_blur_u8, W, H, sigma, ksize, s, d_workspace);

        // 2. 轉 Float
        core::convert_u8_to_f32_gpu(d_temp_blur_u8, d_temp_blur_f32, num_pixels, s);

        // 3. 計算 Hessian Response
        get_optimal_launch_1d(k_hessianResponse, num_pixels, gridSize, blockSize);
        k_hessianResponse << <gridSize, blockSize, 0, s >> > (d_temp_blur_f32, d_temp_response, W, H, mode);

        // 4. 正規化 MinMax 並轉回 Uint8
        core::normalize_minmax_f32_u8_gpu(d_temp_response, d_out, num_pixels, s);

        // [移除] 所有的 cudaMalloc 和 cudaFree，這裡只做運算，極致快速且安全
    }

}
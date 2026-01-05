// AOI_SDK\core_cv\src\imgproc\core_ops.cu

#include "core_cv/imgproc/core_ops.hpp"
#include "core_cv/base/cuda_utils.hpp"
#include "core_kernels.cuh"
#include <vector>
#include <cmath>
#include <thrust/device_ptr.h>
#include <thrust/extrema.h>
#include <thrust/execution_policy.h>


namespace core {

    // 1D 運算
    void brighten_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, int bright, cudaStream_t s) {
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_brighten_u8, N, gridSize, blockSize);
        // 注意：這裡傳 N 而不是 W, H
        k_brighten_u8 <<<gridSize, blockSize, 0, s >>> (d_in, d_out, N, bright);
        CUDA_CHECK(cudaGetLastError());
    }

    void threshold_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, uint8_t thresh, cudaStream_t s) {
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_threshold_u8, N, gridSize, blockSize);
        k_threshold_u8 <<<gridSize, blockSize, 0, s >>> (d_in, d_out, N, thresh);
        CUDA_CHECK(cudaGetLastError());
    }

    void invert_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s) {
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_invert_u8, N, gridSize, blockSize);
        k_invert_u8 <<<gridSize, blockSize, 0, s >>> (d_in, d_out, N);
        CUDA_CHECK(cudaGetLastError());
    }

    void gaussianBlur_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, int ksize, cudaStream_t s) {
        int num_pixels = W * H;
        int gridSize, blockSize;
        dim3 grid2d, block2d;

        // 1. 記憶體分配 (Float 暫存)
        float* d_f32_in = nullptr;
        float* d_f32_temp = nullptr;
        float* d_f32_out = nullptr;
        float* d_mask = nullptr;

        CUDA_CHECK(cudaMalloc(&d_f32_in, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_f32_temp, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_f32_out, num_pixels * sizeof(float)));

        // 2. 準備 Mask (Host -> Device)
        if (ksize % 2 == 0) ksize++; // 確保奇數
        std::vector<float> h_kernel(ksize);
        float sum = 0.0f;
        int r = ksize / 2;
        float two_sigma_sq = 2.0f * sigma * sigma;

        for (int i = 0; i < ksize; ++i) {
            int x = i - r;
            h_kernel[i] = expf(-(x * x) / two_sigma_sq);
            sum += h_kernel[i];
        }
        for (int i = 0; i < ksize; ++i) h_kernel[i] /= sum;

        CUDA_CHECK(cudaMalloc(&d_mask, ksize * sizeof(float)));
        CUDA_CHECK(cudaMemcpyAsync(d_mask, h_kernel.data(), ksize * sizeof(float), cudaMemcpyHostToDevice, s));

        // 3. 轉 Float
        get_optimal_launch_1d(k_u8_to_f32, num_pixels, gridSize, blockSize);
        k_u8_to_f32 << <gridSize, blockSize, 0, s >> > (d_in, d_f32_in, num_pixels);

        // 4. 分離式卷積 (Row -> Col)
        get_optimal_launch_2d(k_gaussianBlurRow, W, H, grid2d, block2d);
        k_gaussianBlurRow << <grid2d, block2d, 0, s >> > (d_f32_in, d_f32_temp, W, H, d_mask, ksize);
        k_gaussianBlurCol << <grid2d, block2d, 0, s >> > (d_f32_temp, d_f32_out, W, H, d_mask, ksize);

        // 5. 轉回 Uint8
        get_optimal_launch_1d(k_f32_to_u8_clamp, num_pixels, gridSize, blockSize);
        k_f32_to_u8_clamp << <gridSize, blockSize, 0, s >> > (d_f32_out, d_out, num_pixels);

        // 6. 清理
        CUDA_CHECK(cudaFree(d_f32_in));
        CUDA_CHECK(cudaFree(d_f32_temp));
        CUDA_CHECK(cudaFree(d_f32_out));
        CUDA_CHECK(cudaFree(d_mask));
    }

    // 2D 運算 (Convolution & ZeroBorder)
    void zero_border_u8_gpu(uint8_t* d_gray, int roiW, int roiH, int t, cudaStream_t s) {
        dim3 grid, block;
        get_optimal_launch_2d(k_zeroBorder_u8, roiW, roiH, grid, block);
        k_zeroBorder_u8 <<<grid, block, 0, s >>> (d_gray, roiW, roiH, t);
        CUDA_CHECK(cudaGetLastError());
    }

    void convolution_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, const float* d_mask, int maskSize, cudaStream_t s) {
        dim3 grid, block;
        get_optimal_launch_2d(k_convolution_u8, W, H, grid, block);
        k_convolution_u8 <<<grid, block, 0, s >>> (d_in, d_out, W, H, d_mask, maskSize);
        CUDA_CHECK(cudaGetLastError());
    }

    void calcColumnBackground_u8_gpu(const uint8_t* d_in, uint8_t* d_bg_out, int W, int H, float sigmaFactor, cudaStream_t s) {
        // 這個 Kernel 每個 Thread 處理一個 Column，所以總量是 W
        int gridSize, blockSize;
        get_optimal_launch_1d(k_calcColumnBackground_u8, W, gridSize, blockSize);
        k_calcColumnBackground_u8 << <gridSize, blockSize, 0, s >> > (d_in, d_bg_out, W, H, sigmaFactor);
        CUDA_CHECK(cudaGetLastError());
    }

    void expandBackground_u8_gpu(const uint8_t* d_bg_in, uint8_t* d_img_out, int W, int H, cudaStream_t s) {
        // 這個 Kernel 處理所有像素，所以總量是 N
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_expandBackground_u8, N, gridSize, blockSize);
        k_expandBackground_u8 << <gridSize, blockSize, 0, s >> > (d_bg_in, d_img_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

    void subtractBackgroundShift_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s) {
        // 這個 Kernel 處理所有像素，所以總量是 N
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_subtractBackgroundShift_u8, N, gridSize, blockSize);
        k_subtractBackgroundShift_u8 << <gridSize, blockSize, 0, s >> > (d_in, d_bg, d_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

    void subtractBackgroundAbs_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s) {
        // 這個 Kernel 處理所有像素，所以總量是 N
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_subtractBackgroundAbs_u8, N, gridSize, blockSize);
        k_subtractBackgroundAbs_u8 << <gridSize, blockSize, 0, s >> > (d_in, d_bg, d_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

    // --- 新增 Sobel ---
    void sobel_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s) {
        dim3 grid, block;
        get_optimal_launch_2d(k_sobelMagnitude_u8, W, H, grid, block);
        k_sobelMagnitude_u8 << <grid, block, 0, s >> > (d_in, d_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

    void hessianRidge_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, const char* mode_str, cudaStream_t s) {
        int num_pixels = W * H;
        int gridSize, blockSize;
        dim3 grid2d, block2d;

        // 1. 解析模式
        RidgeMode mode = RidgeMode::VERTICAL;
        if (strcmp(mode_str, "horizontal") == 0) mode = RidgeMode::HORIZONTAL;
        else if (strcmp(mode_str, "both") == 0) mode = RidgeMode::BOTH;

        // 2. 記憶體分配
        float* d_f32_in = nullptr;
        float* d_f32_temp = nullptr;
        float* d_f32_smooth = nullptr;
        float* d_response = nullptr;
        float* d_mask = nullptr; // 用於存放 1D 高斯核

        CUDA_CHECK(cudaMalloc(&d_f32_in, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_f32_temp, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_f32_smooth, num_pixels * sizeof(float)));
        CUDA_CHECK(cudaMalloc(&d_response, num_pixels * sizeof(float)));

        // 3. 轉 float
        get_optimal_launch_1d(k_u8_to_f32, num_pixels, gridSize, blockSize);
        k_u8_to_f32 << <gridSize, blockSize, 0, s >> > (d_in, d_f32_in, num_pixels);

        // 4. Gaussian Blur (Separable 1D + Global Memory Mask)
        // -------------------------------------------------------
        // 4.1 計算 Kernel Size
        int ksize = (int)(6.0f * sigma + 1.0f);
        if (ksize % 2 == 0) ksize++;

        // 4.2 產生 1D 高斯核
        std::vector<float> h_kernel(ksize);
        float sum = 0.0f;
        int r = ksize / 2;
        float two_sigma_sq = 2.0f * sigma * sigma;

        for (int i = 0; i < ksize; ++i) {
            int x = i - r;
            float val = expf(-(x * x) / two_sigma_sq);
            h_kernel[i] = val;
            sum += val;
        }
        for (int i = 0; i < ksize; ++i) h_kernel[i] /= sum;

        // 4.3 上傳 Mask 到 GPU Global Memory
        CUDA_CHECK(cudaMalloc(&d_mask, ksize * sizeof(float)));
        CUDA_CHECK(cudaMemcpyAsync(d_mask, h_kernel.data(), ksize * sizeof(float), cudaMemcpyHostToDevice, s));

        // 4.4 執行 Pass 1: Row Convolution (In -> Temp)
        get_optimal_launch_2d(k_gaussianBlurRow, W, H, grid2d, block2d);
        // 注意：最後一個參數傳入 d_mask 指標
        k_gaussianBlurRow << <grid2d, block2d, 0, s >> > (d_f32_in, d_f32_temp, W, H, d_mask, ksize);

        // 4.5 執行 Pass 2: Column Convolution (Temp -> Smooth)
        k_gaussianBlurCol << <grid2d, block2d, 0, s >> > (d_f32_temp, d_f32_smooth, W, H, d_mask, ksize);
        // -------------------------------------------------------

        // 5. 計算 Hessian Response
        get_optimal_launch_1d(k_hessianResponse, num_pixels, gridSize, blockSize);
        k_hessianResponse << <gridSize, blockSize, 0, s >> > (d_f32_smooth, d_response, W, H, mode);

        // 6. 正規化 MinMax
        thrust::device_ptr<float> d_ptr(d_response);
        auto result = thrust::minmax_element(thrust::cuda::par.on(s), d_ptr, d_ptr + num_pixels);

        float min_val, max_val;
        CUDA_CHECK(cudaMemcpyAsync(&min_val, result.first.get(), sizeof(float), cudaMemcpyDeviceToHost, s));
        CUDA_CHECK(cudaMemcpyAsync(&max_val, result.second.get(), sizeof(float), cudaMemcpyDeviceToHost, s));
        CUDA_CHECK(cudaStreamSynchronize(s));

        // 7. 轉回 uint8
        get_optimal_launch_1d(k_normalizeMinMax_f32_u8, num_pixels, gridSize, blockSize);
        k_normalizeMinMax_f32_u8 << <gridSize, blockSize, 0, s >> > (d_response, d_out, num_pixels, min_val, max_val);

        // 8. 清理
        CUDA_CHECK(cudaFree(d_f32_in));
        CUDA_CHECK(cudaFree(d_f32_temp));
        CUDA_CHECK(cudaFree(d_f32_smooth));
        CUDA_CHECK(cudaFree(d_response));
        CUDA_CHECK(cudaFree(d_mask)); // 記得釋放 mask
    }

}
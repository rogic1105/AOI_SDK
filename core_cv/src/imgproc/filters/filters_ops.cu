// AOI_SDK\core_cv\src\imgproc\filters\filters_ops.cu

#include "core_cv/base/cuda_utils.hpp"
#include "core_cv/imgproc/core_utils.hpp"


#include "filters_kernels.cuh"
#include <vector>
#include <cmath>
#include <thrust/device_ptr.h>
#include <thrust/extrema.h>
#include <thrust/execution_policy.h>


namespace core {

    void convolution_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, const float* d_mask, int maskSize, cudaStream_t s) {
        dim3 grid, block;
        get_optimal_launch_2d(k_convolution_u8, W, H, grid, block);
        k_convolution_u8 << <grid, block, 0, s >> > (d_in, d_out, W, H, d_mask, maskSize);
        CUDA_CHECK(cudaGetLastError());
    }

    void gaussianBlur_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, int ksize, cudaStream_t s, void* d_workspace) {
        int num_pixels = W * H;
        dim3 grid2d, block2d;

        float* d_f32_in = nullptr;
        float* d_f32_temp = nullptr;
        float* d_f32_out = nullptr;
        float* d_mask = nullptr;

        bool need_free = false;

        // 確保 ksize 為奇數
        if (ksize % 2 == 0) ksize++;

        if (d_workspace != nullptr) {
            uint8_t* ptr = (uint8_t*)d_workspace;
            d_f32_in = (float*)(ptr);
            d_f32_temp = (float*)(ptr + num_pixels * sizeof(float));
            d_f32_out = (float*)(ptr + 2 * num_pixels * sizeof(float));
            d_mask = (float*)(ptr + 3 * num_pixels * sizeof(float));
        }
        else {
            need_free = true;
            CUDA_CHECK(cudaMalloc(&d_f32_in, num_pixels * sizeof(float)));
            CUDA_CHECK(cudaMalloc(&d_f32_temp, num_pixels * sizeof(float)));
            CUDA_CHECK(cudaMalloc(&d_f32_out, num_pixels * sizeof(float)));
            CUDA_CHECK(cudaMalloc(&d_mask, ksize * sizeof(float))); // 這裡直接分配 ksize 大小即可
        }

        // 準備 Mask Host Data
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

        // [修正] 移除原本這裡錯誤的 cudaMalloc(&d_mask...)
        // 只做 Memcpy。如果 d_mask 是 workspace，就 copy 到 workspace；如果是 malloc，就 copy 到 malloc。
        CUDA_CHECK(cudaMemcpyAsync(d_mask, h_kernel.data(), ksize * sizeof(float), cudaMemcpyHostToDevice, s));

        // 3. 轉 Float
        core::convert_u8_to_f32_gpu(d_in, d_f32_in, num_pixels, s);

        // 4. 分離式卷積
        get_optimal_launch_2d(k_gaussianBlurRow, W, H, grid2d, block2d);
        k_gaussianBlurRow << <grid2d, block2d, 0, s >> > (d_f32_in, d_f32_temp, W, H, d_mask, ksize);
        k_gaussianBlurCol << <grid2d, block2d, 0, s >> > (d_f32_temp, d_f32_out, W, H, d_mask, ksize);

        // 5. 轉回 Uint8
        core::convert_f32_to_u8_clamp_gpu(d_f32_out, d_out, num_pixels, s);

        // 6. 清理
        if (need_free) {
            CUDA_CHECK(cudaFree(d_f32_in));
            CUDA_CHECK(cudaFree(d_f32_temp));
            CUDA_CHECK(cudaFree(d_f32_out));
            CUDA_CHECK(cudaFree(d_mask));
        }
    }
}
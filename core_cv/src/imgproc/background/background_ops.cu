// AOI_SDK\core_cv\src\imgproc\background\background_ops.cu

#include "core_cv/base/cuda_utils.hpp"
#include "background_kernels.cuh"
#include <vector>
#include <cmath>
#include <thrust/device_ptr.h>
#include <thrust/extrema.h>
#include <thrust/execution_policy.h>


namespace core {

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


}
// core_ops.cu

#include "core/core_ops.hpp"
#include "../include/core/core_kernels.cuh"
#include "../include/core/cuda_utils.hpp"


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

    void subtractBackground_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s) {
        // 這個 Kernel 處理所有像素，所以總量是 N
        int N = W * H;
        int gridSize, blockSize;
        get_optimal_launch_1d(k_subtractBackground_u8, N, gridSize, blockSize);

        k_subtractBackground_u8 << <gridSize, blockSize, 0, s >> > (d_in, d_bg, d_out, W, H);
        CUDA_CHECK(cudaGetLastError());
    }

}
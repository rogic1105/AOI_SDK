//AOI_SDK\core_cv_api\src\export_api.cpp

#include "export_c/export_api.h"

// 引用內部核心運算標頭檔
#include "core_cv/imgproc/core_background.hpp"
#include "core_cv/imgproc/core_enhance.hpp"
#include "core_cv/imgproc/core_features.hpp"
#include "core_cv/imgproc/core_filters.hpp"
#include "core_cv/imgproc/core_utils.hpp"
#include <cuda_runtime.h>
#include <iostream>
#include <algorithm> // for std::exception

// 內部輔助巨集：檢查 CUDA 錯誤並回傳錯誤碼
#define CHECK_CUDA(call)                                          \
  {                                                               \
    cudaError_t err = call;                                       \
    if (err != cudaSuccess) {                                     \
      std::cerr << "[CoreCV API] CUDA Error: "                    \
                << cudaGetErrorString(err) << "\n";               \
      return CORE_CV_ERROR_CUDA;                                  \
    }                                                             \
  }

int CoreCV_Brighten(const uint8_t* src_ptr, int width, int height, int value, uint8_t* dst_ptr) {
    if (!src_ptr || !dst_ptr) return CORE_CV_ERROR_NULL_POINTER;
    if (width <= 0 || height <= 0) return CORE_CV_ERROR_INVALID_PARAM;

    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    uint8_t* d_in = nullptr;
    uint8_t* d_out = nullptr;

    try {
        // 1. Allocate GPU Memory
        CHECK_CUDA(cudaMalloc(&d_in, size));
        CHECK_CUDA(cudaMalloc(&d_out, size));

        // 2. Upload Data (Host -> Device)
        CHECK_CUDA(cudaMemcpy(d_in, src_ptr, size, cudaMemcpyHostToDevice));

        // 3. Execute Kernel
        core::brighten_u8_gpu(d_in, d_out, width, height, value, 0);
        CHECK_CUDA(cudaGetLastError()); // Check launch error
        CHECK_CUDA(cudaDeviceSynchronize()); // Wait for completion

        // 4. Download Data (Device -> Host)
        CHECK_CUDA(cudaMemcpy(dst_ptr, d_out, size, cudaMemcpyDeviceToHost));

        // 5. Free Resources
        cudaFree(d_in);
        cudaFree(d_out);

        return CORE_CV_SUCCESS;
    }
    catch (const std::exception& e) {
        std::cerr << "[CoreCV API] Exception: " << e.what() << "\n";
        if (d_in) cudaFree(d_in);
        if (d_out) cudaFree(d_out);
        return CORE_CV_ERROR_UNKNOWN;
    }
}

int CoreCV_Threshold(const uint8_t* src_ptr, int width, int height, uint8_t threshold, uint8_t* dst_ptr) {
    if (!src_ptr || !dst_ptr) return CORE_CV_ERROR_NULL_POINTER;
    if (width <= 0 || height <= 0) return CORE_CV_ERROR_INVALID_PARAM;

    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    uint8_t* d_in = nullptr;
    uint8_t* d_out = nullptr;

    try {
        CHECK_CUDA(cudaMalloc(&d_in, size));
        CHECK_CUDA(cudaMalloc(&d_out, size));

        CHECK_CUDA(cudaMemcpy(d_in, src_ptr, size, cudaMemcpyHostToDevice));

        core::threshold_u8_gpu(d_in, d_out, width, height, threshold, 0);
        CHECK_CUDA(cudaGetLastError());
        CHECK_CUDA(cudaDeviceSynchronize());

        CHECK_CUDA(cudaMemcpy(dst_ptr, d_out, size, cudaMemcpyDeviceToHost));

        cudaFree(d_in);
        cudaFree(d_out);

        return CORE_CV_SUCCESS;
    }
    catch (const std::exception& e) {
        std::cerr << "[CoreCV API] Exception: " << e.what() << "\n";
        if (d_in) cudaFree(d_in);
        if (d_out) cudaFree(d_out);
        return CORE_CV_ERROR_UNKNOWN;
    }
}

int CoreCV_Invert(const uint8_t* src_ptr, int width, int height, uint8_t* dst_ptr) {
    // 1. 基本參數檢查
    if (!src_ptr || !dst_ptr) return CORE_CV_ERROR_NULL_POINTER;
    if (width <= 0 || height <= 0) return CORE_CV_ERROR_INVALID_PARAM;

    size_t size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    uint8_t* d_in = nullptr;
    uint8_t* d_out = nullptr;

    try {
        // 2. Allocate GPU Memory
        CHECK_CUDA(cudaMalloc(&d_in, size));
        CHECK_CUDA(cudaMalloc(&d_out, size));

        // 3. Upload Data (Host -> Device)
        CHECK_CUDA(cudaMemcpy(d_in, src_ptr, size, cudaMemcpyHostToDevice));

        // 4. Execute Kernel
        // 注意：這裡呼叫的是 core_ops.hpp 裡的 wrapper function
        // 請確保你在 core_ops.cu 裡已經實作了 invert_u8_gpu 來啟動 k_invert_u8
        core::invert_u8_gpu(d_in, d_out, width, height, 0);
        
        CHECK_CUDA(cudaGetLastError());
        CHECK_CUDA(cudaDeviceSynchronize());

        // 5. Download Data (Device -> Host)
        CHECK_CUDA(cudaMemcpy(dst_ptr, d_out, size, cudaMemcpyDeviceToHost));

        // 6. Free Resources
        cudaFree(d_in);
        cudaFree(d_out);

        return CORE_CV_SUCCESS;
    }
    catch (const std::exception& e) {
        std::cerr << "[CoreCV API] Exception: " << e.what() << "\n";
        // 確保發生例外時也有釋放記憶體
        if (d_in) cudaFree(d_in);
        if (d_out) cudaFree(d_out);
        return CORE_CV_ERROR_UNKNOWN;
    }
}

int CoreCV_Convolution(const uint8_t* src_ptr, int width, int height, const float* mask_ptr, int mask_size, uint8_t* dst_ptr) {
    if (!src_ptr || !dst_ptr || !mask_ptr) return CORE_CV_ERROR_NULL_POINTER;
    if (width <= 0 || height <= 0 || mask_size <= 0) return CORE_CV_ERROR_INVALID_PARAM;

    size_t img_size = static_cast<size_t>(width) * height * sizeof(uint8_t);
    size_t mask_bytes = static_cast<size_t>(mask_size) * mask_size * sizeof(float);

    uint8_t* d_in = nullptr;
    uint8_t* d_out = nullptr;
    float* d_mask = nullptr;

    try {
        // 1. Allocate GPU Memory (包含 Mask)
        CHECK_CUDA(cudaMalloc(&d_in, img_size));
        CHECK_CUDA(cudaMalloc(&d_out, img_size));
        CHECK_CUDA(cudaMalloc(&d_mask, mask_bytes));

        // 2. Upload Data (Image + Mask)
        CHECK_CUDA(cudaMemcpy(d_in, src_ptr, img_size, cudaMemcpyHostToDevice));
        CHECK_CUDA(cudaMemcpy(d_mask, mask_ptr, mask_bytes, cudaMemcpyHostToDevice));

        // 3. Execute Kernel
        core::convolution_u8_gpu(d_in, d_out, width, height, d_mask, mask_size, 0);
        CHECK_CUDA(cudaGetLastError());
        CHECK_CUDA(cudaDeviceSynchronize());

        // 4. Download Data
        CHECK_CUDA(cudaMemcpy(dst_ptr, d_out, img_size, cudaMemcpyDeviceToHost));

        // 5. Free Resources
        cudaFree(d_in);
        cudaFree(d_out);
        cudaFree(d_mask);

        return CORE_CV_SUCCESS;
    }
    catch (const std::exception& e) {
        std::cerr << "[CoreCV API] Exception: " << e.what() << "\n";
        if (d_in) cudaFree(d_in);
        if (d_out) cudaFree(d_out);
        if (d_mask) cudaFree(d_mask);
        return CORE_CV_ERROR_UNKNOWN;
    }
}
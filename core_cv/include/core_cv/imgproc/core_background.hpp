// AOI_SDK\core_cv\include\core_cv\imgproc\core_background.hpp

#pragma once
#include <cstdint>
#include <cuda_runtime.h>

namespace core {

    template <typename T>
    void calcColumnMeans_gpu(const T* d_in, float* d_out, int W, int H, cudaStream_t stream, void* d_workspace);

    template <typename T>
    void calcColumnMax_gpu(const T* d_in, float* d_out, int W, int H, cudaStream_t stream);

    void calcColumnBackground_u8_gpu(const uint8_t* d_in, const float* d_mean, uint8_t* d_out, int W, int H, cudaStream_t s);

    template <typename T>
    void calcColumnMeans_RemoveOutliers_gpu(const T* d_in, float* d_out, int W, int H, float sigma_threshold, cudaStream_t stream);


}
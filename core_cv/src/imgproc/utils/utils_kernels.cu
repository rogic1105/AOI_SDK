// AOI_SDK\core_cv\src\imgproc\utils\utils_kernels.cu

#include "utils_kernels.cuh"
#include "core_cv/base/cuda_utils.hpp"
#include <cmath>




namespace core {

    __global__ void k_zeroBorder_u8(uint8_t* __restrict__ in, int roiW, int roiH, int t) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= roiW || y >= roiH) return;
        if (x < t || x >= roiW - t || y < t || y >= roiH - t) {
            in[y * roiW + x] = 0;
        }
    }

    __global__ void k_f32_to_u8_clamp(const float* __restrict__ in, uint8_t* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx >= N) return;

        float val = in[idx];
        if (val < 0.0f) val = 0.0f;
        else if (val > 255.0f) val = 255.0f;

        out[idx] = (uint8_t)(val + 0.5f); // ¥|³·¤­¤J
    }

    __global__ void k_u8_to_f32(const uint8_t* __restrict__ in, float* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) out[idx] = (float)in[idx];
    }

    __global__ void k_normalizeMinMax_f32_u8(const float* __restrict__ in, uint8_t* __restrict__ out, int N, float minVal, float maxVal) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx >= N) return;

        float range = maxVal - minVal;
        if (range < 1e-6f) {
            out[idx] = 0;
        }
        else {
            float val = (in[idx] - minVal) / range * 255.0f;
            if (val < 0.0f) val = 0.0f;
            if (val > 255.0f) val = 255.0f;
            out[idx] = (uint8_t)val;
        }
    }


}
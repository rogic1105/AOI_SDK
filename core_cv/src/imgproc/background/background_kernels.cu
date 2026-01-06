// AOI_SDK\core_cv\src\imgproc\background\background_kernels.cu

#include "background_kernels.cuh"
#include "core_cv/base/cuda_utils.hpp"
#include <cmath>

namespace core {

    // 計算 Column 背景 (含 Sigma Clipping 離群值剔除)
    __global__ void k_calcColumnBackground_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ background, int W, int H, float sigmaFactor) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        if (x >= W) return;

        // --- Pass 1: 初步計算 Mean & StdDev ---
        float sum = 0.0f;
        float sq_sum = 0.0f;

        for (int y = 0; y < H; ++y) {
            float val = (float)in[y * W + x];
            sum += val;
            sq_sum += val * val;
        }

        float mean = sum / H;
        float variance = (sq_sum / H) - (mean * mean);
        // 使用 fmaxf 確保不對負數開根號
        float std_dev = sqrtf(fmaxf(0.0f, variance));

        // --- Pass 2: 剔除離群值後重算 Mean ---
        float clean_sum = 0.0f;
        int clean_count = 0;
        float threshold = std_dev * sigmaFactor;

        if (threshold < 1.0f) threshold = 1.0f; // 避免除以零或過濾過嚴

        for (int y = 0; y < H; ++y) {
            float val = (float)in[y * W + x];
            if (fabsf(val - mean) <= threshold) {
                clean_sum += val;
                clean_count++;
            }
        }

        // 寫入結果
        if (clean_count > 0) {
            background[x] = (uint8_t)(clean_sum / clean_count + 0.5f);
        }
        else {
            background[x] = (uint8_t)mean;
        }
    }

    // 擴展背景
    __global__ void k_expandBackground_u8(const uint8_t* __restrict__ bg_in, uint8_t* __restrict__ img_out, int W, int H) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        int N = W * H;
        if (idx >= N) return;

        int x = idx % W; // 算出目前像素對應哪一欄
        img_out[idx] = bg_in[x];
    }

    // 減去背景+127
    __global__ void k_subtractBackgroundShift_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        int N = W * H;
        if (idx >= N) return;

        int x = idx % W;

        // 演算法：原圖 - 背景 + 127
        int val = (int)in[idx] - (int)bg[x] + 127;

        if (val < 0) val = 0;
        else if (val > 255) val = 255;

        out[idx] = (uint8_t)val;
    }

    // 減去背景絕對值
    __global__ void k_subtractBackgroundAbs_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        int N = W * H;
        if (idx >= N) return;

        int x = idx % W;
        int val = abs((int)in[idx] - (int)bg[x]);

        // 絕對值必定在 0-255，無需 clamp
        out[idx] = (uint8_t)val;
    }


}
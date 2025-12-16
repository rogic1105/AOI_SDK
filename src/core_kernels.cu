// core_kernels.cu
#include "core/core_kernels.cuh"
#include <cmath>

// 這是為了讓 VSCode 的 IntelliSense 不要報錯，不影響實際編譯
#ifdef __INTELLISENSE__
#define __global__
#define __device__
#define __host__
inline void __syncthreads() {}
struct dim3 { int x; int y; int z; };
dim3 blockIdx, blockDim, threadIdx, gridDim;
#endif


namespace core {

    // 1. 亮度 (1D)
    __global__ void k_brighten_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, int bright) {
        // 全域 1D 索引
        int idx = blockIdx.x * blockDim.x + threadIdx.x;

        if (idx < N) {
            int v = (int)in[idx] + bright;
            if (v < 0) v = 0; else if (v > 255) v = 255;
            out[idx] = (uint8_t)v;
        }
    }

    // 2. 二值化 (1D)
    __global__ void k_threshold_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, uint8_t thresh) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) {
            out[idx] = (in[idx] >= thresh) ? 255 : 0;
        }
    }

    // 3. 反轉 (1D)
    __global__ void k_invert_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) {
            out[idx] = (uint8_t)(255 - in[idx]);
        }
    }

    // 4. 邊框 (維持 2D)
    __global__ void k_zeroBorder_u8(uint8_t* __restrict__ in, int roiW, int roiH, int t) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= roiW || y >= roiH) return;
        if (x < t || x >= roiW - t || y < t || y >= roiH - t) {
            in[y * roiW + x] = 0;
        }
    }

    // 5. 卷積 (維持 2D)
    __global__ void k_convolution_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int maskSize) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= W || y >= H) return;

        int r = maskSize / 2;
        float sum = 0.0f;

        for (int ky = -r; ky <= r; ++ky) {
            for (int kx = -r; kx <= r; ++kx) {
                int curX = x + kx;
                int curY = y + ky;

                // 邊緣鏡射 101
                if (curX < 0) curX = -curX; else if (curX >= W) curX = 2 * (W - 1) - curX;
                if (curY < 0) curY = -curY; else if (curY >= H) curY = 2 * (H - 1) - curY;

                // Clamp 確保安全
                if (curX < 0) curX = 0; else if (curX >= W) curX = W - 1;
                if (curY < 0) curY = 0; else if (curY >= H) curY = H - 1;

                sum += (float)in[curY * W + curX] * d_mask[(ky + r) * maskSize + (kx + r)];
            }
        }
        float abs_sum = fabsf(sum); // 負數變正數，讓黑色變白色的邊緣也能顯示
        if (abs_sum > 255.0f) abs_sum = 255.0f;

        out[y * W + x] = (uint8_t)(abs_sum + 0.5f);
    }

    // [新增] 1. 計算 Column 背景 (含 Sigma Clipping 離群值剔除)
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

    // [新增] 2. 擴展背景
    __global__ void k_expandBackground_u8(const uint8_t* __restrict__ bg_in, uint8_t* __restrict__ img_out, int W, int H) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        int N = W * H;
        if (idx >= N) return;

        int x = idx % W; // 算出目前像素對應哪一欄
        img_out[idx] = bg_in[x];
    }

    // [新增] 3. 減去背景
    __global__ void k_subtractBackground_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H) {
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
}
// AOI_SDK\core_cv\src\core_kernels.cu
#include "core_kernels.cuh"
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

    //  亮度 (1D)
    __global__ void k_brighten_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, int bright) {
        // 全域 1D 索引
        int idx = blockIdx.x * blockDim.x + threadIdx.x;

        if (idx < N) {
            int v = (int)in[idx] + bright;
            if (v < 0) v = 0; else if (v > 255) v = 255;
            out[idx] = (uint8_t)v;
        }
    }

    // 二值化 (1D)
    __global__ void k_threshold_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N, uint8_t thresh) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) {
            out[idx] = (in[idx] >= thresh) ? 255 : 0;
        }
    }

    // 反轉 (1D)
    __global__ void k_invert_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) {
            out[idx] = (uint8_t)(255 - in[idx]);
        }
    }

    // 邊框 (維持 2D)
    __global__ void k_zeroBorder_u8(uint8_t* __restrict__ in, int roiW, int roiH, int t) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= roiW || y >= roiH) return;
        if (x < t || x >= roiW - t || y < t || y >= roiH - t) {
            in[y * roiW + x] = 0;
        }
    }

	// Float 轉 Uint8(單純截斷，不正規化)
    __global__ void k_f32_to_u8_clamp(const float* __restrict__ in, uint8_t* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx >= N) return;

        float val = in[idx];
        if (val < 0.0f) val = 0.0f;
        else if (val > 255.0f) val = 255.0f;

        out[idx] = (uint8_t)(val + 0.5f); // 四雪五入
    }

    // 卷積 (維持 2D)
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

    // Float 版本的卷積 (用於高斯模糊)
    __global__ void k_convolution_f32(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int maskSize) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= W || y >= H) return;

        int r = maskSize / 2;
        float sum = 0.0f;

        // 簡單的 2D 卷積迴圈
        for (int ky = -r; ky <= r; ++ky) {
            for (int kx = -r; kx <= r; ++kx) {
                int curX = x + kx;
                int curY = y + ky;

                // 邊緣處理：Clamp (複製邊緣像素)
                if (curX < 0) curX = 0; else if (curX >= W) curX = W - 1;
                if (curY < 0) curY = 0; else if (curY >= H) curY = H - 1;

                sum += in[curY * W + curX] * d_mask[(ky + r) * maskSize + (kx + r)];
            }
        }
        out[y * W + x] = sum;
    }

    // Pass 1: 水平卷積 (Row)
    __global__ void k_gaussianBlurRow(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int ksize) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (y >= H || x >= W) return;

        int r = ksize / 2;
        float sum = 0.0f;

        for (int k = -r; k <= r; ++k) {
            int curX = x + k;

            if (curX < 0) curX = 0;
            else if (curX >= W) curX = W - 1;

            // 直接讀取 Global Memory (有 L1/L2 Cache 輔助，速度依然很快)
            sum += in[y * W + curX] * d_mask[k + r];
        }

        out[y * W + x] = sum;
    }

    // Pass 2: 垂直卷積 (Column)
    __global__ void k_gaussianBlurCol(const float* __restrict__ in, float* __restrict__ out, int W, int H, const float* __restrict__ d_mask, int ksize) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (y >= H || x >= W) return;

        int r = ksize / 2;
        float sum = 0.0f;

        for (int k = -r; k <= r; ++k) {
            int curY = y + k;

            if (curY < 0) curY = 0;
            else if (curY >= H) curY = H - 1;

            sum += in[curY * W + x] * d_mask[k + r];
        }

        out[y * W + x] = sum;
    }

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
    
    // --- 新增: Sobel Magnitude ---
    __global__ void k_sobelMagnitude_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ out, int W, int H) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (x >= W || y >= H) return;

        // 邊界處理：邊緣設為 0
        if (x < 1 || x >= W - 1 || y < 1 || y >= H - 1) {
            out[y * W + x] = 0;
            return;
        }

        // 讀取 3x3
        // 00 01 02
        // 10 11 12
        // 20 21 22
        int idx = y * W + x;
        int i00 = in[idx - W - 1]; int i01 = in[idx - W]; int i02 = in[idx - W + 1];
        int i10 = in[idx - 1];     /* i11 */              int i12 = in[idx + 1];
        int i20 = in[idx + W - 1]; int i21 = in[idx + W]; int i22 = in[idx + W + 1];

        // Sobel X
        // -1  0  1
        // -2  0  2
        // -1  0  1
        float dx = (float)(i02 + 2 * i12 + i22 - (i00 + 2 * i10 + i20));

        // Sobel Y
        // -1 -2 -1
        //  0  0  0
        //  1  2  1
        float dy = (float)(i20 + 2 * i21 + i22 - (i00 + 2 * i01 + i02));

        // Magnitude
        float mag = sqrtf(dx * dx + dy * dy);

        if (mag > 255.0f) mag = 255.0f;
        out[idx] = (uint8_t)(mag + 0.5f);
    }

    __global__ void k_hessianResponse(const float* __restrict__ img, float* __restrict__ out, int W, int H, RidgeMode mode) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx >= W * H) return;

        int x = idx % W;
        int y = idx / W;

        if (x < 1 || x >= W - 1 || y < 1 || y >= H - 1) {
            out[idx] = 0.0f;
            return;
        }

        // 這裡需要讀 float 類型的輸入
        float p00 = img[(y - 1) * W + (x - 1)];
        float p01 = img[(y - 1) * W + x];
        float p02 = img[(y - 1) * W + (x + 1)];
        float p10 = img[y * W + (x - 1)];
        float p11 = img[y * W + x];
        float p12 = img[y * W + (x + 1)];
        float p20 = img[(y + 1) * W + (x - 1)];
        float p21 = img[(y + 1) * W + x];
        float p22 = img[(y + 1) * W + (x + 1)];

        float val_xx = 0.0f;
        float val_yy = 0.0f;

        // Lxx (Vertical features)
        if (mode == RidgeMode::VERTICAL || mode == RidgeMode::BOTH) {
            val_xx = (p00 + p02 + p20 + p22) + 2.0f * (p10 + p12) - 2.0f * (p01 + p21) - 4.0f * p11;
            // 注意：上面的 mask 簡化寫法其實等於 Sobel(2,0)，標準是 1, -2, 1 卷積
            val_xx = (p00 - 2 * p01 + p02) + 2 * (p10 - 2 * p11 + p12) + (p20 - 2 * p21 + p22);
        }

        // Lyy (Horizontal features)
        if (mode == RidgeMode::HORIZONTAL || mode == RidgeMode::BOTH) {
            val_yy = (p00 - 2 * p10 + p20) + 2 * (p01 - 2 * p11 + p21) + (p02 - 2 * p12 + p22);
        }

        float response = 0.0f;
        if (mode == RidgeMode::VERTICAL) response = fabsf(val_xx);
        else if (mode == RidgeMode::HORIZONTAL) response = fabsf(val_yy);
        else response = fabsf(val_xx) + fabsf(val_yy);

        out[idx] = response;
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

    __global__ void k_u8_to_f32(const uint8_t* __restrict__ in, float* __restrict__ out, int N) {
        int idx = blockIdx.x * blockDim.x + threadIdx.x;
        if (idx < N) out[idx] = (float)in[idx];
    }

}
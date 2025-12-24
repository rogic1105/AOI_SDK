// ncc_kernels.cu

#include <cuda_runtime.h>
#include "core/cuda_utils.hpp"
#include "core/ncc_kernels.cuh"

#include <cuda_runtime.h>
#include "core/cuda_utils.hpp"

#ifdef __INTELLISENSE__
#define __global__
#define __device__
#define __host__
inline void __syncthreads() {}
dim3 blockIdx, blockDim, threadIdx, gridDim;
#endif



namespace core {  // ★ 加上這個 namespace，和 .cuh 一致

    __global__ void ncc_kernel_u8(
        const uint8_t* __restrict__ img, int Wimg, int Himg,
        const float* __restrict__ tpl_c,
        float tpl_energy,
        int Wtpl, int Htpl,
        int Ox, int Oy,
        int outW, int outH,
        float* __restrict__ corr_out)
    {
        int ox = blockIdx.x * blockDim.x + threadIdx.x;
        int oy = blockIdx.y * blockDim.y + threadIdx.y;
        if (ox >= outW || oy >= outH) return;

        int x = Ox + ox;
        int y = Oy + oy;

        const int N = Wtpl * Htpl;
        float sumI = 0.f, sumI2 = 0.f, sumITc = 0.f;

        for (int ty = 0; ty < Htpl; ++ty) {
            const uint8_t* pI = img + (y + ty) * Wimg + x;
            const float* pT = tpl_c + ty * Wtpl;
            for (int tx = 0; tx < Wtpl; ++tx) {
                float I = static_cast<float>(pI[tx]);
                float Tc = pT[tx];
                sumI += I;
                sumI2 += I * I;
                sumITc += I * Tc;
            }
        }

        float varI = sumI2 - (sumI * sumI) / (float)N;
        if (varI < 1e-12f) varI = 1e-12f;
        if (tpl_energy < 1e-12f) tpl_energy = 1e-12f;

        float denom = sqrtf(varI) * sqrtf(tpl_energy);
        corr_out[oy * outW + ox] = sumITc / (denom + 1e-12f);
    }



    __global__ void ncc_kernel_u8_row_sliding(
        const uint8_t* __restrict__ img, int Wimg, int Himg,
        const float* __restrict__ tpl_c, int Wtpl, int Htpl,
        int Ox, int Oy, int outW, int outH,
        float tpl_energy,
        float* __restrict__ corr_out)
    {
        // 一個 block 對應一個 oy；只用 threadIdx.x==0 的 thread
        int oy = blockIdx.x;           // 注意：用 blockIdx.x 當列索引
        if (oy >= outH) return;
        if (threadIdx.x != 0) return;  // 保證每列只有一個 thread 在跑

        // 動態 shared：存模板每列的第一/最後一個係數
        extern __shared__ float smem[];
        float* Tc_first = smem;            // 長度 Htpl
        float* Tc_last = smem + Htpl;     // 長度 Htpl

        // 由單一 thread 載入（Htpl 一般不大）
        for (int ty = 0; ty < Htpl; ++ty) {
            Tc_first[ty] = tpl_c[ty * Wtpl + 0];
            Tc_last[ty] = tpl_c[ty * Wtpl + (Wtpl - 1)];
        }
        __syncthreads();

        // 初始視窗左上角
        const int base_x = Ox;
        const int base_y = Oy + oy;

        // 邊界保護（雖照理 outW/outH 已確保）
        if (base_y < 0 || base_y + Htpl > Himg) return;
        if (base_x < 0 || base_x + Wtpl > Wimg) return;

        // 初始 sumI / sumI2 / sumITc（O(Htpl*Wtpl) 只算一次）
        float sumI = 0.f, sumI2 = 0.f, sumITc = 0.f;
        for (int ty = 0; ty < Htpl; ++ty) {
            const uint8_t* pI = img + (base_y + ty) * Wimg + base_x;
            const float* pT = tpl_c + ty * Wtpl;
            float row_dot = 0.f;
            for (int tx = 0; tx < Wtpl; ++tx) {
                float I = static_cast<float>(pI[tx]);
                float T = pT[tx];
                row_dot += I * T;
                sumI += I;
                sumI2 += I * I;
            }
            sumITc += row_dot;
        }

        auto write_corr = [&](int ox, float sI, float sI2, float sITc) {
            const float N = static_cast<float>(Wtpl * Htpl);
            float varI = sI2 - (sI * sI) / N;
            if (varI < 1e-12f) varI = 1e-12f;
            float te = (tpl_energy < 1e-12f ? 1e-12f : tpl_energy);
            float denom = sqrtf(varI) * sqrtf(te);
            corr_out[oy * outW + ox] = sITc / (denom + 1e-12f);
            };

        // ox = 0
        write_corr(/*ox=*/0, sumI, sumI2, sumITc);

        // 接著線性往右滑動（每步 O(Htpl)）
        for (int ox = 1; ox < outW; ++ox) {
            int xl = base_x + (ox - 1);        // 前一個位置的左欄
            int xr = xl + Wtpl;                // 新進入的右欄

            float addI = 0.f, subI = 0.f;
            float addI2 = 0.f, subI2 = 0.f;
            float delta_corr = 0.f;

            for (int ty = 0; ty < Htpl; ++ty) {
                const uint8_t* pL = img + (base_y + ty) * Wimg + xl;
                const uint8_t* pR = img + (base_y + ty) * Wimg + xr;
                float IL = static_cast<float>(*pL);
                float IR = static_cast<float>(*pR);

                subI += IL;
                subI2 += IL * IL;
                addI += IR;
                addI2 += IR * IR;

                delta_corr += IR * Tc_last[ty] - IL * Tc_first[ty];
            }

            sumI += (addI - subI);
            sumI2 += (addI2 - subI2);
            sumITc += delta_corr;

            write_corr(ox, sumI, sumI2, sumITc);
        }
    }

} // namespace core
// fft_ncc_ops.cu

#include "core/fft_ncc_ops.hpp"
#include "core/cuda_utils.hpp"

#include <cuda_runtime.h>
#include <cufft.h>
#include <cmath>
#include <vector>

#ifdef __INTELLISENSE__
#define __global__
#define __device__
#define __host__
inline void __syncthreads() {}
dim3 blockIdx, blockDim, threadIdx, gridDim;
#endif


// ===== 小工具 =====
static inline int nextPow2(int v) {
    if (v <= 1) return 1;
    v--; v |= v >> 1; v |= v >> 2; v |= v >> 4; v |= v >> 8; v |= v >> 16; v++;
    return v;
}

// R2C 的頻域寬度（列主序的第二維）
static inline int freqWidth(int Q) { return Q / 2 + 1; }

// ===== kernels =====
__global__ void k_pack_u8_to_f_pad(const uint8_t* __restrict__ src, int W, int H,
    float* __restrict__ dst, int P, int Q)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= Q) return;
    float v = 0.f;
    if (y < H && x < W) v = static_cast<float>(src[y * W + x]);
    dst[y * Q + x] = v;
}

__global__ void k_pack_u8_to_f2_pad(const uint8_t* __restrict__ src, int W, int H,
    float* __restrict__ dst, int P, int Q)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= Q) return;
    float v = 0.f;
    if (y < H && x < W) {
        float t = static_cast<float>(src[y * W + x]);
        v = t * t;
    }
    dst[y * Q + x] = v;
}

__global__ void k_pack_tplc_pad(const float* __restrict__ tplc, int Wt, int Ht,
    float* __restrict__ dst, int P, int Q)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= Q) return;
    float v = 0.f;
    if (y < Ht && x < Wt) v = tplc[y * Wt + x];
    dst[y * Q + x] = v;
}

__global__ void k_build_ones_pad(float* __restrict__ dst, int P, int Q, int Ht, int Wt)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= Q) return;
    float v = 0.f;
    if (y < Ht && x < Wt) v = 1.f;
    dst[y * Q + x] = v;
}

// 複數逐點相乘：A *= conj(B)
__global__ void k_mul_conj(cufftComplex* __restrict__ A,
    const cufftComplex* __restrict__ B,
    int P, int Q) // A/B size = P x (Q/2+1)
{
    int fw = Q / 2 + 1;
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= fw) return;
    int i = y * fw + x;
    cufftComplex a = A[i], b = B[i];
    // a * conj(b)
    cufftComplex out;
    out.x = a.x * b.x + a.y * b.y;
    out.y = a.y * b.x - a.x * b.y;
    A[i] = out;
}

// 複數逐點相乘：A *= B
__global__ void k_mul(cufftComplex* __restrict__ A,
    const cufftComplex* __restrict__ B,
    int P, int Q)
{
    int fw = Q / 2 + 1;
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= fw) return;
    int i = y * fw + x;
    cufftComplex a = A[i], b = B[i];
    cufftComplex out;
    out.x = a.x * b.x - a.y * b.y;
    out.y = a.x * b.y + a.y * b.x;
    A[i] = out;
}

__global__ void k_scale(float* __restrict__ buf, int n, float s)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) buf[i] *= s;
}

// 最終把 (sumITc, sumI, sumI2) 裁到有效區並做正規化 + threshold → uint8
__global__ void k_finalize_to_bin(
    const float* __restrict__ sumITc, const float* __restrict__ sumI, const float* __restrict__ sumI2,
    int P, int Q, int Ht, int Wt,
    int outH, int outW,
    float tpl_energy, float corr_th,
    uint8_t* __restrict__ outBin)
{
    int ox = blockIdx.x * blockDim.x + threadIdx.x; // 0..outW-1
    int oy = blockIdx.y * blockDim.y + threadIdx.y; // 0..outH-1
    if (ox >= outW || oy >= outH) return;

    // 有效區偏移（互相關落點）
    int sy = (Ht - 1) + oy;
    int sx = (Wt - 1) + ox;
    int idx = sy * Q + sx;

    float S = sumI[idx];    // sum of I
    float S2 = sumI2[idx];   // sum of I^2
    float C = sumITc[idx];  // sum of I * (T-meanT)

    const float N = float(Wt * Ht);
    const float eps = 1e-12f;

    float varI = S2 - (S * S) / N;
    varI = fmaxf(varI, eps);
    float denom = sqrtf(varI) * sqrtf(fmaxf(tpl_energy, eps));

    float ncc = C / denom;
    outBin[oy * outW + ox] = (ncc >= corr_th) ? 1u : 0u;
}


// conj(A) * B → OUT
__global__ void k_mul_conjA(const cufftComplex* __restrict__ A,
    const cufftComplex* __restrict__ B,
    cufftComplex* __restrict__ OUT,
    int P, int Q) {
    int fw = Q / 2 + 1;
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (y >= P || x >= fw) return;
    int i = y * fw + x;
    cufftComplex a = A[i], b = B[i];
    // conj(a) * b
    cufftComplex out;
    out.x = a.x * b.x + a.y * b.y;
    out.y = -a.y * b.x + a.x * b.y;
    OUT[i] = out;
}

// ===== 主流程 =====


namespace core {

    bool ncc_match_fft_cuda_u8(
        const uint8_t * d_img_u8, int Wimg, int Himg,
        const uint8_t * d_tpl_u8, int Wtpl, int Htpl,
        float corr_th,
        std::vector<uint8_t>&corr_binary_host,
        int& outW, int& outH)
    {
        corr_binary_host.clear();
        outW = Wimg - Wtpl + 1;
        outH = Himg - Htpl + 1;
        if (!d_img_u8 || !d_tpl_u8 || Wimg <= 0 || Himg <= 0 || Wtpl <= 0 || Htpl <= 0) return false;
        if (Wtpl > Wimg || Htpl > Himg) { outW = outH = 0; return true; }
        if (outW <= 0 || outH <= 0) { outW = outH = 0; return true; }

        // 1) host: 模板零均值 + 能量
        std::vector<uint8_t> tpl_u8_host((size_t)Wtpl * Htpl);
        checkCudaErrors(cudaMemcpy(tpl_u8_host.data(), d_tpl_u8,
            (size_t)Wtpl * Htpl, cudaMemcpyDeviceToHost));

        std::vector<float> tpl_c_host((size_t)Wtpl * Htpl);
        double sumT = 0.0;
        for (size_t i = 0; i < tpl_u8_host.size(); ++i) sumT += (double)tpl_u8_host[i];
        double meanT = sumT / double((size_t)Wtpl * Htpl);

        double energy = 0.0;
        for (size_t i = 0; i < tpl_u8_host.size(); ++i) {
            float v = float(tpl_u8_host[i]) - float(meanT);
            tpl_c_host[i] = v;
            energy += double(v) * double(v);
        }
        float tpl_energy = (float)std::max(energy, 1e-12);

        // 2) 決定 pad 尺寸（可換 nextFastSize，但 nextPow2 已足夠）
        int P = nextPow2(Himg + Htpl - 1);
        int Q = nextPow2(Wimg + Wtpl - 1);
        int FW = freqWidth(Q);

        // 3) 分配實/頻域 buffer（實: P*Q, 複: P*FW）
        float* d_img_f = nullptr, * d_img2_f = nullptr, * d_tplc_f = nullptr, * d_ones_f = nullptr;
        cufftComplex* d_ImgF = nullptr, * d_Img2F = nullptr, * d_TplF = nullptr, * d_OnesF = nullptr;
        float* d_sumITc = nullptr, * d_sumI = nullptr, * d_sumI2 = nullptr;
        uint8_t* d_bin = nullptr;

        size_t realN = (size_t)P * Q;
        size_t freqN = (size_t)P * FW;

        try {
            checkCudaErrors(cudaMalloc(&d_img_f, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_img2_f, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_tplc_f, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_ones_f, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_sumITc, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_sumI, realN * sizeof(float)));
            checkCudaErrors(cudaMalloc(&d_sumI2, realN * sizeof(float)));

            checkCudaErrors(cudaMalloc(&d_ImgF, freqN * sizeof(cufftComplex)));
            checkCudaErrors(cudaMalloc(&d_Img2F, freqN * sizeof(cufftComplex)));
            checkCudaErrors(cudaMalloc(&d_TplF, freqN * sizeof(cufftComplex)));
            checkCudaErrors(cudaMalloc(&d_OnesF, freqN * sizeof(cufftComplex)));

            checkCudaErrors(cudaMalloc(&d_bin, (size_t)outW * outH));

            dim3 block(16, 16);
            dim3 gridR((Q + block.x - 1) / block.x, (P + block.y - 1) / block.y);

            // pack: img, img^2, tpl_c, ones
            k_pack_u8_to_f_pad << <gridR, block >> > (d_img_u8, Wimg, Himg, d_img_f, P, Q);
            k_pack_u8_to_f2_pad << <gridR, block >> > (d_img_u8, Wimg, Himg, d_img2_f, P, Q);

            float* d_tplc_small = nullptr;
            checkCudaErrors(cudaMalloc(&d_tplc_small, (size_t)Wtpl * Htpl * sizeof(float)));
            checkCudaErrors(cudaMemcpy(d_tplc_small, tpl_c_host.data(),
                (size_t)Wtpl * Htpl * sizeof(float), cudaMemcpyHostToDevice));
            k_pack_tplc_pad << <gridR, block >> > (d_tplc_small, Wtpl, Htpl, d_tplc_f, P, Q);
            checkCudaErrors(cudaFree(d_tplc_small));

            k_build_ones_pad << <gridR, block >> > (d_ones_f, P, Q, Htpl, Wtpl);
            checkCudaErrors(cudaPeekAtLastError());

            // cuFFT plans
            cufftHandle planR2C, planC2R;
            if (cufftPlan2d(&planR2C, P, Q, CUFFT_R2C) != CUFFT_SUCCESS) throw std::runtime_error("cufftPlan2d R2C failed");
            if (cufftPlan2d(&planC2R, P, Q, CUFFT_C2R) != CUFFT_SUCCESS) { cufftDestroy(planR2C); throw std::runtime_error("cufftPlan2d C2R failed"); }

            // FFT
            if (cufftExecR2C(planR2C, d_img_f, d_ImgF) != CUFFT_SUCCESS) throw std::runtime_error("FFT img");
            if (cufftExecR2C(planR2C, d_img2_f, d_Img2F) != CUFFT_SUCCESS) throw std::runtime_error("FFT img2");
            if (cufftExecR2C(planR2C, d_tplc_f, d_TplF) != CUFFT_SUCCESS) throw std::runtime_error("FFT tplc");
            if (cufftExecR2C(planR2C, d_ones_f, d_OnesF) != CUFFT_SUCCESS) throw std::runtime_error("FFT ones");

            dim3 gridF((FW + block.x - 1) / block.x, (P + block.y - 1) / block.y);

            // 分配一個頻域工作緩衝 (新增)
            cufftComplex* d_WorkF = nullptr;
            checkCudaErrors(cudaMalloc(&d_WorkF, freqN * sizeof(cufftComplex)));

            // ... 略：R2C for d_ImgF, d_TplF, d_Img2F, d_OnesF 都已完成

            // sumITc = ifft( conj(ImgF) * TplF )   ← 方向改這個
            k_mul_conjA << <gridF, block >> > (d_ImgF, d_TplF, d_WorkF, P, Q);
            checkCudaErrors(cudaPeekAtLastError());
            if (cufftExecC2R(planC2R, d_WorkF, d_sumITc) != CUFFT_SUCCESS) throw std::runtime_error("IFFT sumITc");

            // sumI: 不要覆寫 d_ImgF（你現在也不會覆寫了，但這裡給最乾淨的做法）
            k_mul << <gridF, block >> > (d_ImgF, d_OnesF, P, Q);
            if (cufftExecC2R(planC2R, d_ImgF, d_sumI) != CUFFT_SUCCESS) throw std::runtime_error("IFFT sumI");

            // sumI2
            k_mul << <gridF, block >> > (d_Img2F, d_OnesF, P, Q);
            if (cufftExecC2R(planC2R, d_Img2F, d_sumI2) != CUFFT_SUCCESS) throw std::runtime_error("IFFT sumI2");


            // IFFT 縮放
            float scale = 1.0f / float((long long)P * (long long)Q);
            int nReal = (int)realN;
            k_scale << < (nReal + 255) / 256, 256 >> > (d_sumITc, nReal, scale);
            k_scale << < (nReal + 255) / 256, 256 >> > (d_sumI, nReal, scale);
            k_scale << < (nReal + 255) / 256, 256 >> > (d_sumI2, nReal, scale);

            // finalize → 裁有效區 + 正規化 + threshold
            dim3 blockO(16, 16);
            dim3 gridO((outW + blockO.x - 1) / blockO.x, (outH + blockO.y - 1) / blockO.y);
            k_finalize_to_bin << <gridO, blockO >> > (
                d_sumITc, d_sumI, d_sumI2,
                P, Q, Htpl, Wtpl,
                outH, outW,
                tpl_energy, corr_th,
                d_bin);
            checkCudaErrors(cudaPeekAtLastError());
            checkCudaErrors(cudaDeviceSynchronize());

            // 複製回 host
            corr_binary_host.resize((size_t)outW * outH);
            checkCudaErrors(cudaMemcpy(corr_binary_host.data(), d_bin,
                (size_t)outW * outH, cudaMemcpyDeviceToHost));

            // 清理
            cufftDestroy(planR2C);
            cufftDestroy(planC2R);

            cudaFree(d_img_f);  cudaFree(d_img2_f);
            cudaFree(d_tplc_f); cudaFree(d_ones_f);
            cudaFree(d_sumITc); cudaFree(d_sumI); cudaFree(d_sumI2);
            cudaFree(d_ImgF);   cudaFree(d_Img2F); cudaFree(d_TplF); cudaFree(d_OnesF);
            cudaFree(d_bin);
            return true;
        }
        catch (...) {
            if (d_img_f)  cudaFree(d_img_f);
            if (d_img2_f) cudaFree(d_img2_f);
            if (d_tplc_f) cudaFree(d_tplc_f);
            if (d_ones_f) cudaFree(d_ones_f);
            if (d_sumITc) cudaFree(d_sumITc);
            if (d_sumI)   cudaFree(d_sumI);
            if (d_sumI2)  cudaFree(d_sumI2);
            if (d_ImgF)   cudaFree(d_ImgF);
            if (d_Img2F)  cudaFree(d_Img2F);
            if (d_TplF)   cudaFree(d_TplF);
            if (d_OnesF)  cudaFree(d_OnesF);
            if (d_bin)    cudaFree(d_bin);
            return false;
        }


    } // namespace core

}

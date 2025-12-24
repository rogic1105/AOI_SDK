// ncc_ops.cu

#include "core/ncc_ops.hpp"
#include "core/cuda_utils.hpp"
#include "core/ncc_kernels.cuh"
#include <cuda_runtime.h>
#include <vector>
#include <algorithm>
#include <cmath>

#ifdef __INTELLISENSE__
#define __global__
#define __device__
#define __host__
inline void __syncthreads() {}
dim3 blockIdx, blockDim, threadIdx, gridDim;
#endif

namespace core {

    static void make_centered_template_float(
        const uint8_t* tpl_u8, int W, int H,
        std::vector<float>& tpl_c_host, float& tpl_energy)
    {
        const int N = W * H;
        tpl_c_host.resize(N);
        double sumT = 0.0;
        for (int i = 0; i < N; ++i) sumT += (double)tpl_u8[i];
        double meanT = sumT / (double)N;

        double energy = 0.0;
        for (int i = 0; i < N; ++i) {
            float v = (float)tpl_u8[i] - (float)meanT;
            tpl_c_host[i] = v;
            energy += (double)v * (double)v;
        }
        tpl_energy = (float)energy;
    }

    bool ncc_match_cuda_u8(
        const uint8_t* d_img_u8, int Wimg, int Himg,
        const uint8_t* d_tpl_u8, int Wtpl, int Htpl,
        int Oy, int Ox,
        bool search_local, int ext,
        float corr_th,
        std::vector<uint8_t>& corr_binary_host,
        int& outW, int& outH)
    {
        if (Wimg <= 0 || Himg <= 0 || Wtpl <= 0 || Htpl <= 0) return false;
        if (Wtpl > Wimg || Htpl > Himg) return false;

        // 將模板從 device 拉回 host 做去均值，再丟回 device（避免在 kernel 重覆算）
        std::vector<uint8_t> tpl_u8_host((size_t)Wtpl * Htpl);
        checkCudaErrors(cudaMemcpy(tpl_u8_host.data(), d_tpl_u8,
            (size_t)Wtpl * Htpl, cudaMemcpyDeviceToHost));

        std::vector<float> tpl_c_host;
        float tpl_energy = 0.f;
        make_centered_template_float(tpl_u8_host.data(), Wtpl, Htpl, tpl_c_host, tpl_energy);

        int Ox0, Oy0;
        if (search_local) {
            int Hrange = Htpl * ext, Wrange = Wtpl * ext;
            Oy0 = std::max(0, Oy - Hrange);
            Ox0 = std::max(0, Ox - Wrange);
            int Oy1 = std::min(Himg, Oy + Hrange);
            int Ox1 = std::min(Wimg, Ox + Wrange);
            outH = std::max(0, Oy1 - Oy0 - Htpl + 1);
            outW = std::max(0, Ox1 - Ox0 - Wtpl + 1);
        }
        else {
            Oy0 = 0; Ox0 = 0;
            outH = Himg - Htpl + 1;
            outW = Wimg - Wtpl + 1;
        }
        if (outW <= 0 || outH <= 0) { corr_binary_host.clear(); return true; }

        float* d_tpl_c = nullptr;
        checkCudaErrors(cudaMalloc(&d_tpl_c, (size_t)Wtpl * Htpl * sizeof(float)));
        checkCudaErrors(cudaMemcpy(d_tpl_c, tpl_c_host.data(),
            (size_t)Wtpl * Htpl * sizeof(float),
            cudaMemcpyHostToDevice));

        float* d_corr = nullptr;
        checkCudaErrors(cudaMalloc(&d_corr, (size_t)outW * outH * sizeof(float)));

        dim3 block(32, 32);
        dim3 grid((outW + block.x - 1) / block.x,
            (outH + block.y - 1) / block.y);

        ncc_kernel_u8 << <grid, block >> > (
            d_img_u8, Wimg, Himg,
            d_tpl_c, tpl_energy,
            Wtpl, Htpl,
            Ox0, Oy0,
            outW, outH,
            d_corr);

        checkCudaErrors(cudaPeekAtLastError());
        checkCudaErrors(cudaDeviceSynchronize());

        std::vector<float> corr_host((size_t)outW * outH);
        checkCudaErrors(cudaMemcpy(corr_host.data(), d_corr,
            (size_t)outW * outH * sizeof(float),
            cudaMemcpyDeviceToHost));

        corr_binary_host.resize((size_t)outW * outH);
        for (size_t i = 0; i < (size_t)outW * outH; ++i)
            corr_binary_host[i] = (corr_host[i] >= corr_th) ? 1u : 0u;

        checkCudaErrors(cudaFree(d_corr));
        checkCudaErrors(cudaFree(d_tpl_c));
        return true;
    }

    /**
     */


    static void make_centered_template_float_host(
        const uint8_t* tpl_u8, int W, int H,
        std::vector<float>& tpl_c_host, float& tpl_energy)
    {
        const int N = W * H;
        tpl_c_host.resize(N);
        double sumT = 0.0;
        for (int i = 0; i < N; ++i) sumT += (double)tpl_u8[i];
        double meanT = sumT / (double)N;

        double energy = 0.0;
        for (int i = 0; i < N; ++i) {
            float v = (float)tpl_u8[i] - (float)meanT;
            tpl_c_host[i] = v;
            energy += (double)v * (double)v;
        }
        tpl_energy = (float)energy;
    }

    bool ncc_match_cuda_u8_hostTpl_ws(
        NccWorkspace& ws,
        const uint8_t* d_img_u8, int Wimg, int Himg,
        const uint8_t* tpl_u8_host, int Wtpl, int Htpl,
        int Oy, int Ox,
        bool search_local, int ext,
        float corr_th,
        std::vector<uint8_t>& corr_binary_host,
        int& outW, int& outH)
    {
        if (Wimg <= 0 || Himg <= 0 || Wtpl <= 0 || Htpl <= 0) return false;
        if (Wtpl > Wimg || Htpl > Himg) return false;

        // 決定 output 範圍
        int Ox0, Oy0;
        if (search_local) {
            int Hrange = Htpl * ext, Wrange = Wtpl * ext;
            Oy0 = std::max(0, Oy - Hrange);
            Ox0 = std::max(0, Ox - Wrange);
            int Oy1 = std::min(Himg, Oy + Hrange);
            int Ox1 = std::min(Wimg, Ox + Wrange);
            outH = std::max(0, Oy1 - Oy0 - Htpl + 1);
            outW = std::max(0, Ox1 - Ox0 - Wtpl + 1);
        }
        else {
            Oy0 = 0; Ox0 = 0;
            outH = Himg - Htpl + 1;
            outW = Wimg - Wtpl + 1;
        }
        if (outW <= 0 || outH <= 0) { corr_binary_host.clear(); return true; }

        // 準備工作區
        ws.init_stream();

        // Host：模板去均值
        static thread_local std::vector<float> tpl_c_host;
        float tpl_energy = 0.f;
        make_centered_template_float_host(tpl_u8_host, Wtpl, Htpl, tpl_c_host, tpl_energy);

        // Device：d_tpl_c
        if (Wtpl > ws.cap_tplW || Htpl > ws.cap_tplH || ws.d_tpl_c == nullptr) {
            if (ws.d_tpl_c) cudaFree(ws.d_tpl_c), ws.d_tpl_c = nullptr;
            checkCudaErrors(cudaMalloc(&ws.d_tpl_c, (size_t)Wtpl * Htpl * sizeof(float)));
            ws.cap_tplW = Wtpl; ws.cap_tplH = Htpl;
        }
        checkCudaErrors(cudaMemcpyAsync(ws.d_tpl_c, tpl_c_host.data(),
            (size_t)Wtpl * Htpl * sizeof(float), cudaMemcpyHostToDevice, ws.stream));

        // Device：d_corr
        if (outW > ws.cap_outW || outH > ws.cap_outH || ws.d_corr == nullptr) {
            if (ws.d_corr) cudaFree(ws.d_corr), ws.d_corr = nullptr;
            checkCudaErrors(cudaMalloc(&ws.d_corr, (size_t)outW * outH * sizeof(float)));
            ws.cap_outW = outW; ws.cap_outH = outH;
        }

        // Kernel 發射（每列一個 block）
        dim3 grid(outH, 1, 1);
        dim3 block(1, 1, 1);
        size_t smem_bytes = (size_t)2 * Htpl * sizeof(float);

        core::ncc_kernel_u8_row_sliding << <grid, block, smem_bytes, ws.stream >> > (
            d_img_u8, Wimg, Himg,
            ws.d_tpl_c, Wtpl, Htpl,
            Ox0, Oy0, outW, outH,
            tpl_energy,
            ws.d_corr);

        checkCudaErrors(cudaPeekAtLastError());

        // Host：準備輸出（Pinned Host，可重用、非同步拷貝更快）
        size_t need_bytes = (size_t)outW * outH * sizeof(float);
        if (need_bytes > ws.h_corr_pinned_bytes) {
            if (ws.h_corr_pinned) cudaFreeHost(ws.h_corr_pinned), ws.h_corr_pinned = nullptr;
            checkCudaErrors(cudaHostAlloc(&ws.h_corr_pinned, need_bytes, cudaHostAllocDefault));
            ws.h_corr_pinned_bytes = need_bytes;
        }

        checkCudaErrors(cudaMemcpyAsync(ws.h_corr_pinned, ws.d_corr, need_bytes,
            cudaMemcpyDeviceToHost, ws.stream));

        // 在 stream 上等待上述所有工作完成（只在這裡同步一次）
        checkCudaErrors(cudaStreamSynchronize(ws.stream));

        // 轉二值（host）
        corr_binary_host.resize((size_t)outW * outH);
        const float* corr = ws.h_corr_pinned;
        for (size_t i = 0, N = (size_t)outW * outH; i < N; ++i)
            corr_binary_host[i] = (corr[i] >= corr_th) ? 1u : 0u;

        return true;
    }



} // namespace core

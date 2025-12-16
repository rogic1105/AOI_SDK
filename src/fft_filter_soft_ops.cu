// fft_filter_soft_ops.cu

#include "core/fft_filter_soft_ops.hpp"
#include "core/fft_filter_soft_kernels.cuh"
#include "core/cuda_utils.hpp"

#include <cuda_runtime.h>
#include <cufft.h>
#include <vector>
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <cfloat>


static float compute_percentile_host(const float* h_data, int N, float pct) {
    if (N <= 0) return 0.0f;
    float p = std::min(100.0f, std::max(0.0f, pct));
    int k = static_cast<int>(std::round((p / 100.0f) * (N - 1)));
    std::vector<float> tmp(h_data, h_data + N);
    std::nth_element(tmp.begin(), tmp.begin() + k, tmp.end());
    return tmp[k];
}

// ============================ Main API ============================

void compute_defect_seg_mask_fft(
    const uint8_t* d_img,
    int width, int height, float percentile,
    uint8_t** d_spectrum_out, // 裝置端頻譜圖，呼叫端釋放
    uint8_t** d_recon_u8      // 裝置端重建灰階，呼叫端釋放
) {
    if (!d_img || width <= 0 || height <= 0) {
        throw std::invalid_argument("FftFilterSoftGPU: 無效的輸入參數");
    }

    const int N = width * height;
    const int threads = 256;
    const int blocks = (N + threads - 1) / threads;

    // 裝置暫存
    cufftComplex* d_input = nullptr, * d_freq = nullptr, * d_fshift = nullptr, * d_high = nullptr, * d_low = nullptr;
    float* d_mag = nullptr, * d_spec_mag = nullptr, * d_recon_mag = nullptr, * d_tmp = nullptr;

    // ✅ 這些是「內部暫存」，用單指標
    uint8_t* d_bw = nullptr, * d_overlay = nullptr;

    // ✅ 輸出緩衝：用雙指標給呼叫端；cudaMalloc 時傳「雙指標本身」
    checkCudaErrors(cudaMalloc(d_spectrum_out, N * sizeof(uint8_t))); // OK，本來就對
    checkCudaErrors(cudaMalloc(d_recon_u8, N * sizeof(uint8_t))); // ❌原本用了 &d_recon_u8，需改成這樣

    // 其餘配置
    checkCudaErrors(cudaMalloc(&d_input, N * sizeof(cufftComplex)));
    checkCudaErrors(cudaMalloc(&d_freq, N * sizeof(cufftComplex)));
    checkCudaErrors(cudaMalloc(&d_fshift, N * sizeof(cufftComplex)));
    checkCudaErrors(cudaMalloc(&d_high, N * sizeof(cufftComplex)));
    checkCudaErrors(cudaMalloc(&d_low, N * sizeof(cufftComplex)));
    checkCudaErrors(cudaMalloc(&d_mag, N * sizeof(float)));
    checkCudaErrors(cudaMalloc(&d_spec_mag, N * sizeof(float)));
    checkCudaErrors(cudaMalloc(&d_recon_mag, N * sizeof(float)));
    checkCudaErrors(cudaMalloc(&d_bw, N * sizeof(uint8_t)));     // ✅ 單指標
    checkCudaErrors(cudaMalloc(&d_overlay, 3 * N * sizeof(uint8_t))); // ✅ 單指標

    const int tmp_blocks = (N + threads - 1) / threads;
    checkCudaErrors(cudaMalloc(&d_tmp, tmp_blocks * sizeof(float)));

    // 1) 灰階 → 複數
    input_to_complex << <blocks, threads >> > (d_img, d_input, N);
    checkCudaErrors(cudaGetLastError());

    // 2) FFT
    cufftHandle plan;
    checkCufftErrors(cufftPlan2d(&plan, height, width, CUFFT_C2C));
    checkCufftErrors(cufftExecC2C(plan, d_input, d_freq, CUFFT_FORWARD));

    // 3) shift
    fftshift2D << <blocks, threads >> > (d_freq, d_fshift, width, height);
    checkCudaErrors(cudaGetLastError());

    // 4) 幅度
    compute_magnitude << <blocks, threads >> > (d_fshift, d_mag, N);
    checkCudaErrors(cudaGetLastError());

    // 5) 百分位閾值（host）
    std::vector<float> h_mag(N);
    checkCudaErrors(cudaMemcpy(h_mag.data(), d_mag, N * sizeof(float), cudaMemcpyDeviceToHost));
    float thr = compute_percentile_host(h_mag.data(), N, percentile);

    // 6) 高/低頻遮罩
    apply_mask << <blocks, threads >> > (d_fshift, d_mag, thr, d_high, d_low, N);
    checkCudaErrors(cudaGetLastError());

    // 7) 頻譜可視化（算 high 的幅度）
    compute_magnitude << <blocks, threads >> > (d_high, d_spec_mag, N);
    checkCudaErrors(cudaGetLastError());

    // 8) reduce min/max（略同你原本）
    float minv, maxv;
    reduce_min << <tmp_blocks, threads, threads * sizeof(float) >> > (d_spec_mag, d_tmp, N);
    checkCudaErrors(cudaGetLastError());
    {
        std::vector<float> h_tmp(tmp_blocks);
        checkCudaErrors(cudaMemcpy(h_tmp.data(), d_tmp, tmp_blocks * sizeof(float), cudaMemcpyDeviceToHost));
        minv = log1pf(*std::min_element(h_tmp.begin(), h_tmp.end()));
    }
    reduce_max << <tmp_blocks, threads, threads * sizeof(float) >> > (d_spec_mag, d_tmp, N);
    checkCudaErrors(cudaGetLastError());
    {
        std::vector<float> h_tmp(tmp_blocks);
        checkCudaErrors(cudaMemcpy(h_tmp.data(), d_tmp, tmp_blocks * sizeof(float), cudaMemcpyDeviceToHost));
        maxv = log1pf(*std::max_element(h_tmp.begin(), h_tmp.end()));
    }

    // 9) 生成頻譜圖（✅ 注意解參考）
    compute_spectrum_from_mag << <blocks, threads >> > (d_spec_mag, *d_spectrum_out, N, minv, maxv);
    checkCudaErrors(cudaGetLastError());

    // 10) 反 shift → IFFT
    fftshift2D << <blocks, threads >> > (d_low, d_freq, width, height);
    checkCudaErrors(cudaGetLastError());
    checkCufftErrors(cufftExecC2C(plan, d_freq, d_input, CUFFT_INVERSE));

    // 11) 重建灰階（幅度→u8，✅ 注意解參考）
    compute_recon_magnitude << <blocks, threads >> > (d_input, d_recon_mag, N);
    checkCudaErrors(cudaGetLastError());
    //dbg_sync("recon_mag kernel");
    //dbg_dump_f32_minmax("recon_mag", d_recon_mag, N);

    float minr, maxr;
    reduce_min << <tmp_blocks, threads, threads * sizeof(float) >> > (d_recon_mag, d_tmp, N);
    checkCudaErrors(cudaGetLastError());
    {
        std::vector<float> h_tmp(tmp_blocks);
        checkCudaErrors(cudaMemcpy(h_tmp.data(), d_tmp, tmp_blocks * sizeof(float), cudaMemcpyDeviceToHost));
        minr = *std::min_element(h_tmp.begin(), h_tmp.end());
    }
    reduce_max << <tmp_blocks, threads, threads * sizeof(float) >> > (d_recon_mag, d_tmp, N);
    checkCudaErrors(cudaGetLastError());
    {
        std::vector<float> h_tmp(tmp_blocks);
        checkCudaErrors(cudaMemcpy(h_tmp.data(), d_tmp, tmp_blocks * sizeof(float), cudaMemcpyDeviceToHost));
        maxr = *std::max_element(h_tmp.begin(), h_tmp.end());
    }

    reconstruction_from_mag << <blocks, threads >> > (d_recon_mag, *d_recon_u8, N, minr, maxr);
    checkCudaErrors(cudaGetLastError());
    //dbg_sync("recon_u8 kernel");
    //dbg_dump_u8("recon_u8", *d_recon_u8, N);


    // 14) 清理（❗不要釋放輸出給呼叫端的緩衝）
    checkCufftErrors(cufftDestroy(plan));
    checkCudaErrors(cudaFree(d_input));
    checkCudaErrors(cudaFree(d_freq));
    checkCudaErrors(cudaFree(d_fshift));
    checkCudaErrors(cudaFree(d_high));
    checkCudaErrors(cudaFree(d_low));
    checkCudaErrors(cudaFree(d_mag));
    checkCudaErrors(cudaFree(d_spec_mag));
    checkCudaErrors(cudaFree(d_recon_mag));
    checkCudaErrors(cudaFree(d_tmp));


}


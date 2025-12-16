// fft_ncc_ops.cu

#pragma once
#include <cstdint>
#include <vector>

namespace core {

    /**
     * FFT-based NCC (TM_CCOEFF_NORMED 等價)
     * - 影像與模板：Gray8
     * - 回傳二值 NCC map (0/1)，outW/outH = Himg-Htpl+1, Wimg-Wtpl+1
     * - 所有 heavy 計算在 GPU（cuFFT），含 SumI / SumI2 的滑動視窗合計
     */
    bool ncc_match_fft_cuda_u8(
        const uint8_t* d_img_u8, int Wimg, int Himg,
        const uint8_t* d_tpl_u8, int Wtpl, int Htpl,
        float corr_th,
        std::vector<uint8_t>& corr_binary_host,
        int& outW, int& outH);

} // namespace core

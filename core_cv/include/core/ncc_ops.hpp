// ncc_ops.hpp

#pragma once
#include <cstdint>
#include <vector>

namespace core {

    /**
     * CUDA 版 NCC（TM_CCOEFF_NORMED 等價）
     *  - 影像/模板均為 Gray8 (uint8)
     *  - 允許局部搜尋（以 (Oy,Ox) 為中心，範圍 = ext * 模板尺寸）
     *  - 也可全圖搜尋（search_local=false）
     *  - 內部會將模板轉為 float 並去均值，避免重複計算
     *
     * @param d_img_u8   [in] 裝置端原圖指標 (Himg x Wimg)
     * @param Wimg,Himg  [in] 原圖尺寸
     * @param d_tpl_u8   [in] 裝置端模板指標 (Htpl x Wtpl)
     * @param Wtpl,Htpl  [in] 模板尺寸
     * @param Oy,Ox      [in] 搜尋中心（對應原圖座標）
     * @param search_local [in] 是否做局部搜尋
     * @param ext        [in] 局部搜尋半徑比例（視窗大小 = 模板尺寸 * ext）
     * @param corr_th    [in] NCC 門檻（0~1），會回傳二值圖（>=th → 1）
     * @param corr_binary_host [out] Host 端二值 NCC 結果（outH*outW，0/1）
     * @param outW,outH  [out] NCC map 寬/高
     * @return true=成功；false=失敗
     */

    bool ncc_match_cuda_u8(
        const uint8_t* d_img_u8, int Wimg, int Himg,
        const uint8_t* d_tpl_u8, int Wtpl, int Htpl,
        int Oy, int Ox,
        bool search_local, int ext,
        float corr_th,
        std::vector<uint8_t>& corr_binary_host,
        int& outW, int& outH);

    /**
     */

    struct NccWorkspace {
        // device
        uint8_t* d_img_u8 = nullptr; // 外部可自行上傳一次 ROI 後重用
        float* d_tpl_c = nullptr;
        float* d_corr = nullptr;

        // host pinned（可選，但建議）
        float* h_corr_pinned = nullptr;
        size_t    h_corr_pinned_bytes = 0;

        int cap_imgW = 0, cap_imgH = 0;
        int cap_tplW = 0, cap_tplH = 0;
        int cap_outW = 0, cap_outH = 0;

        cudaStream_t stream = nullptr;

        void init_stream() {
            if (!stream) cudaStreamCreate(&stream);
        }
        void destroy() {
            if (d_tpl_c) cudaFree(d_tpl_c), d_tpl_c = nullptr;
            if (d_corr)  cudaFree(d_corr), d_corr = nullptr;
            if (h_corr_pinned) { cudaFreeHost(h_corr_pinned); h_corr_pinned = nullptr; h_corr_pinned_bytes = 0; }
            if (stream) cudaStreamDestroy(stream), stream = nullptr;
            // d_img_u8 由呼叫端管理（通常在外層 ROI 迴圈已存在）
        }
    };

    bool ncc_match_cuda_u8_hostTpl_ws(  // 使用工作區，不做多餘配/釋放
        NccWorkspace& ws,
        const uint8_t* d_img_u8, int Wimg, int Himg,
        const uint8_t* tpl_u8_host, int Wtpl, int Htpl,
        int Oy, int Ox,
        bool search_local, int ext,
        float corr_th,
        std::vector<uint8_t>& corr_binary_host,
        int& outW, int& outH);



    /**
     */





} // namespace core

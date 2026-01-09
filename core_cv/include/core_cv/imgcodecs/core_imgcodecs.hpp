// AOI_SDK\core_cv\include\core_cv\imgcodecs\core_imgcodecs.hpp

#pragma once
#include <cstdint>

namespace core {

    /**
     * @brief CPU 端快速讀取並縮放圖片 (用於 UI 預覽)
     * * @param filepath 檔案路徑
     * @param target_width 目標寬度 (例如 1000)
     * @param out_buffer 接收像素的緩衝區 (必須預先分配足夠大小)
     * @param out_real_w 回傳實際寬度
     * @param out_real_h 回傳實際高度
     * @return int 0:成功, <0:失敗
     */
    int load_thumbnail_cpu(
        const char* filepath,
        int target_width,
        uint8_t* out_buffer,
        int* out_real_w,
        int* out_real_h
    );
}
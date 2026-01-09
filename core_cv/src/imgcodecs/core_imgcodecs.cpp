#include "core_cv/imgcodecs/core_imgcodecs.hpp"

#include "stb/stb_image.h" 

#include <cmath>
#include <algorithm>

namespace core {

    // 內部 Helper: 簡單的 Nearest Neighbor 縮放
    // 不需要 SIMD，因為瓶頸在記憶體跳躍存取
    static void resize_gray_nearest(const uint8_t* src, int w, int h, uint8_t* dst, int new_w, int new_h) {
        float scale_x = (float)w / new_w;
        float scale_y = (float)h / new_h;

        // 這裡可以做簡單的 OpenMP 平行化，對大圖縮放會有幫助
        // #pragma omp parallel for 
        for (int y = 0; y < new_h; ++y) {
            // 預先計算 Y 軸偏移，減少乘法次數
            const uint8_t* src_row = src + (int)(y * scale_y) * w;
            uint8_t* dst_row = dst + y * new_w;

            for (int x = 0; x < new_w; ++x) {
                int src_x = (int)(x * scale_x);
                dst_row[x] = src_row[src_x];
            }
        }
    }

    int load_thumbnail_cpu(const char* filepath, int target_width, uint8_t* out_buffer, int* out_real_w, int* out_real_h) {
        if (!filepath || !out_buffer) return -1;

        int w, h, channels;

        // 1. 讀取圖片 (最耗時的部分)
        // force_channels = 1 強制轉灰階，省去後續轉灰階的時間
        uint8_t* img = stbi_load(filepath, &w, &h, &channels, 1);

        if (!img) return -2; // 讀檔失敗

        // 2. 計算目標尺寸
        float ratio = (float)h / w;
        int new_h = (int)(target_width * ratio);

        // 3. 執行縮放
        resize_gray_nearest(img, w, h, out_buffer, target_width, new_h);

        // 4. 回傳資訊
        if (out_real_w) *out_real_w = target_width;
        if (out_real_h) *out_real_h = new_h;

        // 5. 釋放原始大圖記憶體
        stbi_image_free(img);

        return 0;
    }
}
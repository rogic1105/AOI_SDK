// image_convert_utils.cpp

#include "core/image_convert_utils.hpp"
#include <cstring> 
#include <stdexcept>

static inline bool validate_params(const unsigned char* input_data, int W, int H, int inChannels, int outputChannels) {
    if (!input_data) return false;
    if (W <= 0 || H <= 0) return false;
    if (inChannels <= 0) return false;
    if (!(outputChannels == 1 || outputChannels == 3)) return false;
    return true;
}

bool image_channel_to_buffer(
    const unsigned char* input_data,
    int W, int H, int inChannels,
    uint8_t* out_buffer,
    size_t buffer_size,
    int outputChannels)
{
    if (!validate_params(input_data, W, H, inChannels, outputChannels)) return false;
    const size_t pxCount = static_cast<size_t>(W) * static_cast<size_t>(H);
    const size_t need = pxCount * static_cast<size_t>(outputChannels);
    if (!out_buffer || buffer_size < need) return false;

    // 常用灰階係數（ITU-R BT.601）
    constexpr float KR = 0.299f;
    constexpr float KG = 0.587f;
    constexpr float KB = 0.114f;

    // 快速路徑：輸入與輸出通道相同（直接 memcpy）
    if (inChannels == outputChannels) {
        // 注意：如果 inChannels == outputChannels == 3，資料排列相同，直接複製
        // 若 inChannels == outputChannels == 1，同樣直接複製
        std::memcpy(out_buffer, input_data, need);
        return true;
    }

    // 處理各種轉換情況（只寫入 out_buffer）
    if (outputChannels == 1) {
        // 輸出灰階
        if (inChannels == 1) {
            std::memcpy(out_buffer, input_data, pxCount);
            return true;
        }
        else if (inChannels == 2) {
            // gray + alpha -> 取第一通道
            for (size_t i = 0; i < pxCount; ++i) {
                out_buffer[i] = input_data[i * 2 + 0];
            }
            return true;
        }
        else {
            // inChannels >= 3 : 用加權公式
            for (size_t i = 0; i < pxCount; ++i) {
                size_t inIdx = i * static_cast<size_t>(inChannels);
                uint8_t r = input_data[inIdx + 0];
                uint8_t g = (inChannels >= 2) ? input_data[inIdx + 1] : r;
                uint8_t b = (inChannels >= 3) ? input_data[inIdx + 2] : r;
                out_buffer[i] = static_cast<uint8_t>(KR * r + KG * g + KB * b + 0.5f);
            }
            return true;
        }
    }
    else {
        // outputChannels == 3 : 輸出 RGB
        if (inChannels == 1) {
            // from gray -> replicate
            for (size_t i = 0; i < pxCount; ++i) {
                uint8_t g = input_data[i];
                size_t outIdx = i * 3;
                out_buffer[outIdx + 0] = g;
                out_buffer[outIdx + 1] = g;
                out_buffer[outIdx + 2] = g;
            }
            return true;
        }
        else if (inChannels == 2) {
            // gray + alpha -> replicate gray
            for (size_t i = 0; i < pxCount; ++i) {
                uint8_t g = input_data[i * 2 + 0];
                size_t outIdx = i * 3;
                out_buffer[outIdx + 0] = g;
                out_buffer[outIdx + 1] = g;
                out_buffer[outIdx + 2] = g;
            }
            return true;
        }
        else {
            // inChannels >=3 : copy first 3 channels (ignore alpha)
            for (size_t i = 0; i < pxCount; ++i) {
                size_t inIdx = i * static_cast<size_t>(inChannels);
                size_t outIdx = i * 3;
                out_buffer[outIdx + 0] = input_data[inIdx + 0];
                out_buffer[outIdx + 1] = input_data[inIdx + 1];
                out_buffer[outIdx + 2] = input_data[inIdx + 2];
            }
            return true;
        }
    }
}

bool image_channel_to_vector(
    const unsigned char* input_data,
    int W, int H, int inChannels,
    std::vector<uint8_t>& output,
    int outputChannels)
{
    if (!validate_params(input_data, W, H, inChannels, outputChannels)) return false;
    const size_t pxCount = static_cast<size_t>(W) * static_cast<size_t>(H);
    const size_t need = pxCount * static_cast<size_t>(outputChannels);
    output.resize(need); // 只配置一次
    return image_channel_to_buffer(input_data, W, H, inChannels, output.data(), need, outputChannels);
}

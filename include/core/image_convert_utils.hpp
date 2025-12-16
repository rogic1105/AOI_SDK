// ImageCpuToGpu.cu

#pragma once
#include <vector>
#include <cstdint>

// outputChannels 只接受 1 或 3
// - input_data: stbi_load 回傳的資料 (row-major)
// - W,H: 圖片寬高
// - inChannels: stbi_load 回傳的通道數 (1/2/3/4)
// - output: 輸出緩衝（會 resize 到 W*H*outputChannels）
// - outputChannels: 1 => 灰階，3 => RGB
// 回傳 true = 成功
bool image_channel_to_vector(
    const unsigned char* input_data,
    int W, int H, int inChannels,
    std::vector<uint8_t>& output,
    int outputChannels);

// 裸指標版本（輸出由呼叫方提供緩衝，buffer_size 應至少為 W*H*outputChannels）
bool image_channel_to_buffer(
    const unsigned char* input_data,
    int W, int H, int inChannels,
    uint8_t* out_buffer,
    size_t buffer_size,
    int outputChannels);

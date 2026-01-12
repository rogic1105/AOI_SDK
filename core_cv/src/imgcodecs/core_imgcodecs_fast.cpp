// AOI_SDK\core_cv\src\imgcodecs\core_imgcodecs_fast.cpp

// [關鍵修正] 必須放在任何 #include 之前
#define _CRT_SECURE_NO_WARNINGS 

#include "core_cv/imgcodecs/core_imgcodecs_fast.hpp"
#include <cstdio>
#include <vector>
#include <cstring>
#include <iostream>
#include <cmath> // std::abs

namespace core {

#pragma pack(push, 1)
    struct BmpHeader {
        uint16_t signature; // 'BM'
        uint32_t fileSize;
        uint16_t reserved1;
        uint16_t reserved2;
        uint32_t dataOffset;
    };

    struct BmpInfoHeader {
        uint32_t headerSize; // 40
        int32_t width;
        int32_t height;
        uint16_t planes;     // 1
        uint16_t bpp;        // 8
        uint32_t compression;// 0
        uint32_t imageSize;  // 0 or w*h
        int32_t xRes;
        int32_t yRes;
        uint32_t colorsUsed; // 256
        uint32_t colorsImportant;
    };
#pragma pack(pop)

    bool fast_write_bmp_8bit(const std::string& filepath, int w, int h, const uint8_t* data) {
        FILE* f = fopen(filepath.c_str(), "wb");
        if (!f) return false;

        // 1. 準備 Header
        const int paletteSize = 1024;
        const int headerSize = sizeof(BmpHeader) + sizeof(BmpInfoHeader);
        const int offset = headerSize + paletteSize;

        // Padding 計算
        int stride = (w + 3) & (~3);
        int imageSize = stride * h;
        int fileSize = offset + imageSize;

        BmpHeader fileHeader = { 0x4D42, (uint32_t)fileSize, 0, 0, (uint32_t)offset };
        // 注意 height 存為負值 (-h) 代表 Top-Down，方便檢視
        BmpInfoHeader infoHeader = { 40, w, -h, 1, 8, 0, (uint32_t)imageSize, 2835, 2835, 256, 0 };

        // 2. 寫入 Header
        fwrite(&fileHeader, sizeof(fileHeader), 1, f);
        fwrite(&infoHeader, sizeof(infoHeader), 1, f);

        // 3. 寫入調色盤
        uint8_t palette[1024];
        for (int i = 0; i < 256; ++i) {
            palette[i * 4 + 0] = i; // B
            palette[i * 4 + 1] = i; // G
            palette[i * 4 + 2] = i; // R
            palette[i * 4 + 3] = 0; // A
        }
        fwrite(palette, 1, 1024, f);

        // 4. 寫入像素
        if (stride == w) {
            fwrite(data, 1, (size_t)w * h, f);
        }
        else {
            std::vector<uint8_t> padding(stride - w, 0);
            for (int y = 0; y < h; ++y) {
                fwrite(data + y * w, 1, w, f);
                fwrite(padding.data(), 1, padding.size(), f);
            }
        }

        fclose(f);
        return true;
    }

    bool fast_read_bmp_8bit(const std::string& filepath, int& w, int& h, uint8_t* out_buffer, int buffer_size) {
        FILE* f = fopen(filepath.c_str(), "rb");
        if (!f) return false;

        BmpHeader fileHeader;
        BmpInfoHeader infoHeader;

        if (fread(&fileHeader, sizeof(fileHeader), 1, f) != 1) { fclose(f); return false; }
        if (fileHeader.signature != 0x4D42) { fclose(f); return false; }

        if (fread(&infoHeader, sizeof(infoHeader), 1, f) != 1) { fclose(f); return false; }

        w = infoHeader.width;
        h = std::abs(infoHeader.height);

        if (infoHeader.bpp != 8) {
            fclose(f);
            std::cerr << "[FastRead] Error: Not an 8-bit BMP\n";
            return false;
        }

        int stride = (w + 3) & (~3);
        size_t dataSize = (size_t)stride * h;

        if (buffer_size < dataSize) {
            fclose(f);
            std::cerr << "[FastRead] Error: Buffer too small\n";
            return false;
        }

        fseek(f, fileHeader.dataOffset, SEEK_SET);
        size_t readCount = fread(out_buffer, 1, dataSize, f);
        fclose(f);

        return readCount == dataSize;
    }
}
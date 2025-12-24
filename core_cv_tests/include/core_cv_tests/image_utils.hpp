// TestApp/src/test_utils.hpp
#pragma once

#include <string>
#include <vector>
#include <iostream>
#include <stdexcept>
#include <filesystem> 


#include "stb/stb_image.h"
#include "stb/stb_image_write.h"

#include "cpp_utils/terminal_colors.hpp"


namespace fs = std::filesystem;
const std::string OUTPUT_DIR = "out";

struct TestImage {
    int w = 0, h = 0, c = 0;
    uint8_t* data = nullptr;

    // 1. 預設建構子
    TestImage() = default;

    // 2. [關鍵] 禁止複製 (Delete Copy)
    // 防止不小心發生兩個物件指向同一塊記憶體，導致雙重釋放
    TestImage(const TestImage&) = delete;
    TestImage& operator=(const TestImage&) = delete;

    // 3. [關鍵] 實作移動建構子 (Move Constructor)
    // 允許所有權轉移：把別人的 data 搶過來，並把對方設為 nullptr
    TestImage(TestImage&& other) noexcept {
        w = other.w;
        h = other.h;
        c = other.c;
        data = other.data;
        other.data = nullptr; // 這步最重要！確保對方不會釋放記憶體
    }

    // 4. [關鍵] 實作移動賦值 (Move Assignment)
    TestImage& operator=(TestImage&& other) noexcept {
        if (this != &other) {
            // 先釋放自己原本的記憶體
            if (data) stbi_image_free(data);

            // 搶過來
            w = other.w;
            h = other.h;
            c = other.c;
            data = other.data;
            other.data = nullptr; // 設空
        }
        return *this;
    }

    // 解構子維持不變
    ~TestImage() {
        if (data) {
            stbi_image_free(data);
            data = nullptr;
        }
    }
};

inline TestImage LoadImageRaw(const std::string& path) {
    TestImage img;
    img.data = stbi_load(path.c_str(), &img.w, &img.h, &img.c, 0);
    if (!img.data) {
        throw std::runtime_error("Failed to load: " + path);
    }

    std::cout << Color::YELLOW << "[Load] " << path  << Color::RESET << "\n";
    std::cout << Color::YELLOW << " (" << img.w << "x" << img.h << ", " << img.c << "ch)\n" << Color::RESET << "\n";

    return img;
}

// [修改] 存圖 Helper：自動處理路徑與資料夾
inline void SaveImageRaw(const std::string& fileName, int w, int h, int c, const uint8_t* data) {

    // 1. 自動檢查並建立資料夾 (如果 out 不存在)
    if (!fs::exists(OUTPUT_DIR)) {
        fs::create_directory(OUTPUT_DIR);
        std::cout << "[Info] Created directory: " << OUTPUT_DIR << "\n";
    }

    // 2. 自動組合路徑： out + / + fileName
    // fs::path 會自動處理 Windows (\) 或 Linux (/) 的分隔符號
    fs::path fullPath = fs::path(OUTPUT_DIR) / fileName;

    // 3. 自動補上 .bmp 副檔名 (如果沒寫的話)
    if (!fullPath.has_extension()) {
        fullPath.replace_extension(".bmp");
    }

    // 轉成字串給 stbi 使用
    std::string finalPathStr = fullPath.string();

    int ret = stbi_write_bmp(finalPathStr.c_str(), w, h, c, data);

    if (ret) std::cout << "[Save] " << finalPathStr << "\n\n";
    else std::cerr << "[Error] Failed to save " << finalPathStr << "\n";
}

// 轉灰階 helper (為了測試 CoreLib)
inline std::vector<uint8_t> ConvertToGray(const TestImage& img) {
    std::vector<uint8_t> gray(img.w * img.h);
    if (img.c == 1) {
        memcpy(gray.data(), img.data, img.w * img.h);
    }
    else {
        for (int i = 0; i < img.w * img.h; ++i) {
            int offset = i * img.c;
            // BGR or RGB to Gray
            gray[i] = (uint8_t)((img.data[offset] + img.data[offset + 1] + img.data[offset + 2]) / 3);
        }
    }
    return gray;
}
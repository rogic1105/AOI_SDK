// shape_utils.h

#pragma once
#include <vector>
#include <array>
#include <string>
#include <cstdint>

struct RectLResult {
    // 每個 crop 的影像 (平坦 row-major, size = (y1-y0)*(x1-x0))
    std::vector<std::vector<uint8_t>> imgs;
    // 每個 crop 的座標 (y0, x0, y1, x1)
    std::vector<std::array<int, 4>> coords;
    // 每個 crop 對應的 shape (string: "rectangle" or "L")
    std::vector<std::string> shapes;
};

// input_img: pointer to H*W uint8_t (binary-like: 0 or >0). 若你的來源不是二值，請先轉成 0/非0。
// H, W: height, width
RectLResult find_rect_or_L(const uint8_t* input_img, int H, int W);

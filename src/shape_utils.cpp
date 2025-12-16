#include "core/shape_utils.hpp"

#include <algorithm>
#include <cstring> 
#include <cassert>
#include <vector>
#include <string>
#include <map>
#include <functional>


static std::vector<int> diff_positions_row(const uint8_t* img, int H, int W, int row) {
    std::vector<int> pos;
    if (W < 2) return pos;
    const uint8_t* row_ptr = img + row * W;
    for (int x = 0; x < W - 1; ++x) {
        uint8_t a = (row_ptr[x] > 0) ? 1u : 0u;
        uint8_t b = (row_ptr[x + 1] > 0) ? 1u : 0u;
        if (a != b) pos.push_back(x);
    }
    return pos;
}

static std::vector<int> diff_positions_col(const uint8_t* img, int H, int W, int col) {
    std::vector<int> pos;
    if (H < 2) return pos;
    for (int y = 0; y < H - 1; ++y) {
        uint8_t a = (img[y * W + col] > 0) ? 1u : 0u;
        uint8_t b = (img[(y + 1) * W + col] > 0) ? 1u : 0u;
        if (a != b) pos.push_back(y);
    }
    return pos;
}


RectLResult find_rect_or_L(const uint8_t* input_img, int H, int W)
{
    RectLResult out;
    if (!input_img || H <= 0 || W <= 0) return out;

    // 娩ち传翴单基 Python  np.where(np.diff(... )!=0)
    auto top = diff_positions_row(input_img, H, W, 0);
    auto btm = diff_positions_row(input_img, H, W, H - 1);
    auto lft = diff_positions_col(input_img, H, W, 0);
    auto rgt = diff_positions_col(input_img, H, W, W - 1);

    const int t_num = static_cast<int>(top.size());
    const int b_num = static_cast<int>(btm.size());
    const int l_num = static_cast<int>(lft.size());
    const int r_num = static_cast<int>(rgt.size());

    // 度セㄧΑずㄏノ helper掉 + ī + push 秖
    auto push_crop = [&](int y0, int y1, int x0, int x1, const std::string& shape) {
        y0 = std::max(0, std::min(y0, H));
        y1 = std::max(0, std::min(y1, H));
        x0 = std::max(0, std::min(x0, W));
        x1 = std::max(0, std::min(x1, W));
        if (y1 <= y0 || x1 <= x0) return;

        const int hh = y1 - y0;
        const int ww = x1 - x0;
        std::vector<uint8_t> crop(static_cast<size_t>(hh) * ww);
        for (int yy = y0; yy < y1; ++yy) {
            const uint8_t* src = input_img + static_cast<size_t>(yy) * W + x0;
            uint8_t* dst = crop.data() + static_cast<size_t>(yy - y0) * ww;
            std::memcpy(dst, src, static_cast<size_t>(ww));
        }
        out.imgs.push_back(std::move(crop));
        out.coords.push_back({ y0, x0, y1, x1 });
        out.shapes.push_back(shape);
        };

    // -------- rectanglet=2,l=0,r=0,b=2
    if (t_num == 2 && l_num == 0 && r_num == 0 && b_num == 2) {
        push_crop(0, H, top[0], top[1], "rectangle");
        return out;
    }

    // -------- rectangle蛮痻t=4,l=0,r=0,b=4
    if (t_num == 4 && l_num == 0 && r_num == 0 && b_num == 4) {
        push_crop(0, H, top[0], top[1], "rectangle");
        push_crop(0, H, top[2], top[3], "rectangle");
        return out;
    }

    // -------- L娩Τち传: t=4,l=4,r=4,b=4  △ 8  ROI "L"
    if (t_num == 4 && l_num == 4 && r_num == 4 && b_num == 4) {
        push_crop(0, lft[1], top[0], top[1], "L");
        push_crop(0, rgt[1], top[2], top[3], "L");
        push_crop(lft[2], H, btm[0], btm[1], "L");
        push_crop(rgt[2], H, btm[2], btm[3], "L");
        push_crop(lft[0], lft[1], 0, top[1], "L");
        push_crop(rgt[0], rgt[1], top[2], W, "L");
        push_crop(lft[2], lft[3], 0, btm[1], "L");
        push_crop(rgt[2], rgt[3], btm[2], W, "L");
        return out;
    }

    // -------- オ Lt=2,l=2,r=0,b=0
    if (t_num == 2 && l_num == 2 && r_num == 0 && b_num == 0) {
        push_crop(0, lft[1], top[0], top[1], "L");
        push_crop(lft[0], lft[1], 0, top[1], "L");
        return out;
    }

    // --------  Lt=2,l=0,r=2,b=0
    if (t_num == 2 && l_num == 0 && r_num == 2 && b_num == 0) {
        push_crop(0, rgt[1], top[0], top[1], "L");
        push_crop(rgt[0], rgt[1], top[0], W, "L");
        return out;
    }

    // -------- オ Lt=0,l=2,r=0,b=2
    if (t_num == 0 && l_num == 2 && r_num == 0 && b_num == 2) {
        push_crop(lft[0], lft[1], 0, btm[1], "L");
        push_crop(lft[0], H, btm[0], btm[1], "L");
        return out;
    }

    // --------  Lt=0,l=0,r=2,b=2
    if (t_num == 0 && l_num == 0 && r_num == 2 && b_num == 2) {
        push_crop(rgt[0], rgt[1], btm[0], W, "L");
        push_crop(rgt[0], H, btm[0], btm[1], "L");
        return out;
    }

    // -------- よ Lt=4,l=2,r=2,b=0
    if (t_num == 4 && l_num == 2 && r_num == 2 && b_num == 0) {
        push_crop(0, lft[1], top[0], top[1], "L");
        push_crop(lft[0], lft[1], 0, top[1], "L");
        push_crop(0, rgt[1], top[2], top[3], "L");
        push_crop(rgt[0], rgt[1], top[2], W, "L");
        return out;
    }

    // -------- オ凹 Lt=2,l=4,r=0,b=2
    if (t_num == 2 && l_num == 4 && r_num == 0 && b_num == 2) {
        push_crop(0, lft[1], top[0], top[1], "L");
        push_crop(lft[0], lft[1], 0, top[1], "L");
        push_crop(lft[2], lft[3], 0, btm[1], "L");
        push_crop(lft[2], H, btm[0], btm[1], "L");
        return out;
    }

    // -------- よ Lt=0,l=2,r=2,b=4
    if (t_num == 0 && l_num == 2 && r_num == 2 && b_num == 4) {
        push_crop(lft[0], lft[1], 0, btm[1], "L");
        push_crop(lft[0], H, btm[0], btm[1], "L");
        push_crop(rgt[0], rgt[1], btm[2], W, "L");
        push_crop(rgt[0], H, btm[2], btm[3], "L");
        return out;
    }

    // -------- 凹 Lt=2,l=0,r=4,b=2
    if (t_num == 2 && l_num == 0 && r_num == 4 && b_num == 2) {
        push_crop(0, rgt[1], top[0], top[1], "L");
        push_crop(rgt[0], rgt[1], top[0], W, "L");
        push_crop(rgt[2], rgt[3], btm[0], W, "L");
        push_crop(rgt[3], H, btm[0], btm[1], "L");
        return out;
    }

    // ㄤ家Α △ 
    return out;
}

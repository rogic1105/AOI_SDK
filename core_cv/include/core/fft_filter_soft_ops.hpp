// fft_filter_soft_ops.hpp

#pragma once
#include <cstdint>
#include <cuda_runtime.h>


static float compute_percentile_host(const float* h_data, int N, float pct);

// ============================ Main API ============================

void compute_defect_seg_mask_fft(
    const uint8_t* d_img,
    int width, int height, float percentile,
    uint8_t** d_spectrum_out, // ¸Ë¸mºÝÀWÃÐ¹Ï¡A©I¥sºÝÄÀ©ñ
    uint8_t** d_recon_u8      // ¸Ë¸mºÝ­««Ø¦Ç¶¥¡A©I¥sºÝÄÀ©ñ
);




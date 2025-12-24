// ncc_kernels.cuh

#pragma once
#include <cuda_runtime.h>
#include <cstdint>

namespace core {

	// 每像素 +bright（飽和到[0,255]）
	__global__ void ncc_kernel_u8(
        const uint8_t* __restrict__ img, int Wimg, int Himg,
        const float* __restrict__ tpl_c,
        float tpl_energy,
        int Wtpl, int Htpl,
        int Ox, int Oy,
        int outW, int outH,
        float* __restrict__ corr_out);

    __global__ void ncc_kernel_u8_row_sliding(
        const uint8_t* __restrict__ img, int Wimg, int Himg,
        const float* __restrict__ tpl_c, int Wtpl, int Htpl,
        int Ox, int Oy, int outW, int outH,
        float tpl_energy,
        float* __restrict__ corr_out);

}

// AOI_SDK\core_cv\src\imgproc\background\background_kernels.cuh

#pragma once
#include <cuda_runtime.h>
#include <cstdint>

namespace core {

    __global__ void k_calcColumnBackground_u8(const uint8_t* __restrict__ in, uint8_t* __restrict__ background, int W, int H, float sigmaFactor);
    
    __global__ void k_expandBackground_u8(const uint8_t* __restrict__ bg_in, uint8_t* __restrict__ img_out, int W, int H);
    
    __global__ void k_subtractBackgroundShift_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H);
   
    __global__ void k_subtractBackgroundAbs_u8(const uint8_t* __restrict__ in, const uint8_t* __restrict__ bg, uint8_t* __restrict__ out, int W, int H);

}
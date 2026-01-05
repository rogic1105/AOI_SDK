// AOI_SDK\core_cv\include\core_cv\imgproc\core_ops.hpp

#pragma once
#include <cstdint>
#include <cuda_runtime.h>

namespace core {

	void brighten_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, int bright, cudaStream_t s = 0);
	void threshold_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, uint8_t thresh, cudaStream_t s = 0);
	void invert_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
	void gaussianBlur_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, int ksize, cudaStream_t s = 0);
	void zero_border_u8_gpu(uint8_t* d_gray, int roiW, int roiH, int t, cudaStream_t s = 0);
	void convolution_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, const float* d_mask, int maskSize, cudaStream_t s = 0);
	void calcColumnBackground_u8_gpu(const uint8_t* d_in, uint8_t* d_bg_out, int W, int H, float sigmaFactor, cudaStream_t s = 0);
	void expandBackground_u8_gpu(const uint8_t* d_bg_in, uint8_t* d_img_out, int W, int H, cudaStream_t s = 0);
	void subtractBackgroundShift_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
	void subtractBackgroundAbs_u8_gpu(const uint8_t* d_in, const uint8_t* d_bg, uint8_t* d_out, int W, int H, cudaStream_t s);
	void sobel_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, cudaStream_t s = 0);
	void hessianRidge_u8_gpu(const uint8_t* d_in, uint8_t* d_out, int W, int H, float sigma, const char* mode, cudaStream_t s = 0);

}

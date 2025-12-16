// memory_utils.cu

#include "../include/core/memory_utils.h"
#include "../include/core/cuda_utils.hpp"

#include <cuda_runtime.h>


void img_cpu_to_gpu(
    const uint8_t* h_image,
    uint8_t** d_image,
    size_t size
) {

    checkCudaErrors(cudaMalloc(d_image, size * sizeof(uint8_t)));
    checkCudaErrors(cudaMemcpy(*d_image, h_image, size * sizeof(uint8_t), cudaMemcpyHostToDevice));
}

void img_gpu_to_cpu(
    uint8_t* d_image,
    uint8_t* h_image,
    size_t size
) {

    checkCudaErrors(cudaMemcpy(h_image, d_image, size * sizeof(uint8_t), cudaMemcpyDeviceToHost));

}
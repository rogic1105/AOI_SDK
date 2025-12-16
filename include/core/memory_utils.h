// memory_utils.h

#pragma once
#include <cstdint>

void img_cpu_to_gpu(
    const uint8_t* h_image,
    uint8_t** d_image,
    size_t size
);

void img_gpu_to_cpu(
    uint8_t* d_image,
    uint8_t* h_image,
    size_t size
);
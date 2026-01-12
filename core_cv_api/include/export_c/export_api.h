// AOI_SDK\core_cv_api\include\export_c\export_api.h

#ifndef CORE_CV_API_EXPORT_API_H_
#define CORE_CV_API_EXPORT_API_H_

#include <cstdint>
#include <stdbool.h> // for bool in C

#ifdef CORE_CV_API_EXPORTS
#define CORE_CV_API __declspec(dllexport)
#else
#define CORE_CV_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define CORE_CV_SUCCESS 0
#define CORE_CV_ERROR_UNKNOWN -1
#define CORE_CV_ERROR_NULL_POINTER -2
#define CORE_CV_ERROR_INVALID_PARAM -3
#define CORE_CV_ERROR_CUDA -4

    // --- [新增] 記憶體管理 (Pinned Memory) ---
    CORE_CV_API unsigned char* CoreCV_AllocPinned(unsigned long long size);
    CORE_CV_API void CoreCV_FreePinned(unsigned char* ptr);

    // --- [新增] 極速 IO (Fast IO) ---
    CORE_CV_API bool CoreCV_FastReadBMP(const char* filepath, int* w, int* h, unsigned char* outBuffer, int bufferSize);
    CORE_CV_API bool CoreCV_FastWriteBMP(const char* filepath, int w, int h, const unsigned char* inBuffer);


    // --- 影像處理運算子 ---
    CORE_CV_API int CoreCV_Brighten(const uint8_t* src_ptr, int width, int height, int value, uint8_t* dst_ptr);
    CORE_CV_API int CoreCV_Threshold(const uint8_t* src_ptr, int width, int height, uint8_t threshold, uint8_t* dst_ptr);
    CORE_CV_API int CoreCV_Invert(const uint8_t* src_ptr, int width, int height, uint8_t* dst_ptr);
    CORE_CV_API int CoreCV_Convolution(const uint8_t* src_ptr, int width, int height, const float* mask_ptr, int mask_size, uint8_t* dst_ptr);

#ifdef __cplusplus
}
#endif

#endif
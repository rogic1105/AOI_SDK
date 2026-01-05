// AOI_SDK\core_cv_api\include\export_c\export_api.h

#ifndef CORE_CV_API_EXPORT_API_H_
#define CORE_CV_API_EXPORT_API_H_

#include <cstdint>

// 定義 DLL 匯出/匯入巨集
#ifdef CORE_CV_API_EXPORTS
#define CORE_CV_API __declspec(dllexport)
#else
#define CORE_CV_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

    // 定義錯誤碼
#define CORE_CV_SUCCESS 0
#define CORE_CV_ERROR_UNKNOWN -1
#define CORE_CV_ERROR_NULL_POINTER -2
#define CORE_CV_ERROR_INVALID_PARAM -3
#define CORE_CV_ERROR_CUDA -4

    /**
     * @brief 調整影像亮度 (Brighten)
     *
     * @param src_ptr [In] 輸入影像數據 (Host pointer, uint8_t, size = w * h)
     * @param width   [In] 影像寬度
     * @param height  [In] 影像高度
     * @param value   [In] 亮度增減值 (例如 50 或 -50)
     * @param dst_ptr [Out] 輸出影像數據 (Host pointer, 需預先分配記憶體)
     * @return int 0: Success, <0: Error Code
     */
    CORE_CV_API int CoreCV_Brighten(
        const uint8_t* src_ptr,
        int width,
        int height,
        int value,
        uint8_t* dst_ptr);

    /**
     * @brief 二值化影像 (Threshold)
     *
     * @param src_ptr   [In] 輸入影像數據
     * @param width     [In] 影像寬度
     * @param height    [In] 影像高度
     * @param threshold [In] 閥值 (0-255)
     * @param dst_ptr   [Out] 輸出影像數據
     * @return int 0: Success, <0: Error Code
     */
    CORE_CV_API int CoreCV_Threshold(
        const uint8_t* src_ptr,
        int width,
        int height,
        uint8_t threshold,
        uint8_t* dst_ptr);

    /**
     * @brief 反轉影像/負片效果 (Invert)
     *
     * @param src_ptr [In] 輸入影像數據
     * @param width   [In] 影像寬度
     * @param height  [In] 影像高度
     * @param dst_ptr [Out] 輸出影像數據
     * @return int 0: Success, <0: Error Code
     */
    CORE_CV_API int CoreCV_Invert(
        const uint8_t* src_ptr,
        int width,
        int height,
        uint8_t* dst_ptr);

    /**
     * @brief 卷積運算 (Convolution)
     *
     * @param src_ptr   [In] 輸入影像數據
     * @param width     [In] 影像寬度
     * @param height    [In] 影像高度
     * @param mask_ptr  [In] 卷積核數據 (Host pointer, float array)
     * @param mask_size [In] 卷積核大小 (例如 3 代表 3x3)
     * @param dst_ptr   [Out] 輸出影像數據
     * @return int 0: Success, <0: Error Code
     */
    CORE_CV_API int CoreCV_Convolution(
        const uint8_t* src_ptr,
        int width,
        int height,
        const float* mask_ptr,
        int mask_size,
        uint8_t* dst_ptr);



#ifdef __cplusplus
}
#endif

#endif  // CORE_CV_API_EXPORT_API_H_
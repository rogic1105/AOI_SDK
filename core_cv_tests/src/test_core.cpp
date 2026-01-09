// AOI_SDK\core_cv_tests\src\test_core.cpp

#include "core_cv_tests/image_utils.hpp"

#include "core_cv/imgproc/core_background.hpp"
#include "core_cv/imgproc/core_enhance.hpp"
#include "core_cv/imgproc/core_features.hpp"
#include "core_cv/imgproc/core_filters.hpp"
#include "core_cv/imgproc/core_utils.hpp"

#include "core_cv/base/cuda_utils.hpp"
#include "cpp_utils/timer_utils.hpp"
#include "cpp_utils/terminal_colors.hpp"
#include "framework/test_utils.hpp" // [新增] 必須引用這個才能用 GetOutputPath
#include <vector>

void RunCoreTests(const std::string& imgPath) {
    std::cout << Color::CYAN << "\n========= Running Core Tests =========" << Color::RESET << "\n";

    try {

        TestImage src;
        {
            TIME_SCOPE_MS("Load Image");
            src = LoadImageRaw(imgPath);
        }

        std::vector<uint8_t> gray = ConvertToGray(src);
        int W = src.w;
        int H = src.h;
        size_t size = W * H;

        uint8_t* d_in = nullptr, * d_out = nullptr;
        checkCudaErrors(cudaMalloc(&d_in, size));
        checkCudaErrors(cudaMalloc(&d_out, size));

        {
            TIME_SCOPE_MS("Memcpy H2D");
            checkCudaErrors(cudaMemcpy(d_in, gray.data(), size, cudaMemcpyHostToDevice));
        }
        std::vector<uint8_t> h_result(size);

        // --- Test 1: Brighten ---
        {
            TIME_SCOPE_MS_SYNC("Core: Brighten (GPU)", cudaDeviceSynchronize());
            core::brighten_u8_gpu(d_in, d_out, W, H, 50, 0);
        }
        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));


        std::string outPath1 = framework::GetOutputPath("core_cv_tests", "out_core_brighten.bmp");
        stbi_write_bmp(outPath1.c_str(), W, H, 1, h_result.data());
        std::cout << "[Save] " << outPath1 << "\n";


        // --- Test 2: Threshold ---
        {
            TIME_SCOPE_MS_SYNC("Core: Threshold (GPU)", cudaDeviceSynchronize());
            core::threshold_u8_gpu(d_in, d_out, W, H, 128, 0);
        }
        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));


        std::string outPath2 = framework::GetOutputPath("core_cv_tests", "out_core_threshold.bmp");
        stbi_write_bmp(outPath2.c_str(), W, H, 1, h_result.data());
        std::cout << "[Save] " << outPath2 << "\n";


        // --- Test 3: Convolution (Sharpen) ---
        float h_mask[] = { 0, 0, 0, -1, 2, -1, 0, 0, 0 };
        float* d_mask = nullptr;
        checkCudaErrors(cudaMalloc(&d_mask, 9 * sizeof(float)));
        checkCudaErrors(cudaMemcpy(d_mask, h_mask, 9 * sizeof(float), cudaMemcpyHostToDevice));

        {
            TIME_SCOPE_MS_SYNC("Core: Convolution 3x3 (GPU)", cudaDeviceSynchronize());
            core::convolution_u8_gpu(d_in, d_out, W, H, d_mask, 3, 0);
        }
        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));

        // [修改點 3]
        std::string outPath3 = framework::GetOutputPath("core_cv_tests", "out_core_convolution.bmp");
        stbi_write_bmp(outPath3.c_str(), W, H, 1, h_result.data());
        std::cout << "[Save] " << outPath3 << "\n";

        cudaFree(d_in);
        cudaFree(d_out);
        cudaFree(d_mask);

        std::cout << Color::GREEN << "Core Tests Completed." << Color::RESET << "\n";
    }
    catch (const std::exception& e) {
        std::cerr << "Core Test Failed: " << e.what() << "\n";
    }
}
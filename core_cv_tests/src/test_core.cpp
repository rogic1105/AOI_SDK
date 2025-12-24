// TestApp/src/test_core.cpp
#include "core_cv_tests/image_utils.hpp"
#include "core/core_ops.hpp"
#include "core/cuda_utils.hpp"
#include "cpp_utils/timer_utils.hpp" // [新增] 引入你的計時工具
#include "cpp_utils/terminal_colors.hpp"
#include <vector>

void RunCoreTests(const std::string& imgPath) {
    std::cout << Color::CYAN <<"\n========= Running Core Tests =========" << Color::RESET<< "\n";

    try {
        // 1. 準備資料
        TestImage src;
        {
            // 這裡不需要 Sync，因為 LoadImage 是 CPU 運算
            TIME_SCOPE_MS("Load Image");
            src = LoadImageRaw(imgPath);
        }

        std::vector<uint8_t> gray = ConvertToGray(src);
        int W = src.w;
        int H = src.h;
        size_t size = W * H;

        // 準備 GPU 記憶體
        uint8_t* d_in = nullptr, * d_out = nullptr;
        checkCudaErrors(cudaMalloc(&d_in, size));
        checkCudaErrors(cudaMalloc(&d_out, size));

        // 上傳圖片 (H2D 也可以計時，看你需不需要)
        {
            TIME_SCOPE_MS("Memcpy H2D"); // 這裡不需要 Sync，cudaMemcpy 預設會 blocking (除非用 Async)
            checkCudaErrors(cudaMemcpy(d_in, gray.data(), size, cudaMemcpyHostToDevice));
        }
        std::cout << "\n";
        std::vector<uint8_t> h_result(size);

        // --- Test 1: Brighten ---
        {
            // [關鍵] 使用有 SYNC 的巨集，並傳入 cudaDeviceSynchronize()
            // 這樣在離開這個 { } 時，會先等 GPU 做完才結算時間
            TIME_SCOPE_MS_SYNC("Core: Brighten (GPU)", cudaDeviceSynchronize());

            core::brighten_u8_gpu(d_in, d_out, W, H, 50, 0);
        }

        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));
        SaveImageRaw("out_core_brighten", W, H, 1, h_result.data());

        // --- Test 2: Threshold ---
        {
            TIME_SCOPE_MS_SYNC("Core: Threshold (GPU)", cudaDeviceSynchronize());

            core::threshold_u8_gpu(d_in, d_out, W, H, 128, 0);
        }

        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));
        SaveImageRaw("out_core_threshold", W, H, 1, h_result.data());

        // --- Test 3: Convolution (Sharpen) ---
        // 定義一個銳化 Mask
        float h_mask[] = {
             0, 0,  0,
            -1, 2, -1,
             0, 0,  0
        };
        float* d_mask = nullptr;
        checkCudaErrors(cudaMalloc(&d_mask, 9 * sizeof(float)));
        checkCudaErrors(cudaMemcpy(d_mask, h_mask, 9 * sizeof(float), cudaMemcpyHostToDevice));

        {
            TIME_SCOPE_MS_SYNC("Core: Convolution 3x3 (GPU)", cudaDeviceSynchronize());

            core::convolution_u8_gpu(d_in, d_out, W, H, d_mask, 3, 0);
        }

        checkCudaErrors(cudaMemcpy(h_result.data(), d_out, size, cudaMemcpyDeviceToHost));
        SaveImageRaw("out_core_convolution", W, H, 1, h_result.data());

        // 清理
        cudaFree(d_in);
        cudaFree(d_out);
        cudaFree(d_mask);

        std::cout << Color::GREEN << "Core Tests Completed." << Color::RESET << "\n";

    }
    catch (const std::exception& e) {
        std::cerr << "Core Test Failed: " << e.what() << "\n";
    }
}
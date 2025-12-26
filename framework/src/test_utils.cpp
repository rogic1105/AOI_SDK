//AOI_SDK\framework\src\test_utils.cpp

#include "framework/test_utils.hpp"

#include <filesystem>
#include <iostream>
#include <string>

#include "cpp_utils/terminal_colors.hpp"

// ★★★ 強制檢查：如果沒有定義 WORKSPACE_ROOT，直接讓編譯失敗 ★★★
// 這強迫使用者必須正確設定 Directory.Build.props，而不是讓程式亂猜路徑。
#ifndef REPO_ROOT
#error "REPO_ROOT is not defined! Please check your Directory.Build.props."
#endif

namespace fs = std::filesystem;

namespace framework {

    // 實作：取得輸出路徑並自動建立資料夾
    std::string GetOutputPath(const std::string& suiteName, const std::string& fileName) {
        fs::path root = REPO_ROOT;

        // 組合路徑: <Root>/artifacts/<REPO_ROOT>/<FileName>
        fs::path outputDir = root / "artifacts" / suiteName;
        fs::path fullPath = outputDir / fileName;

        // 自動建立目錄 (如果不存在)
        if (!fs::exists(outputDir)) {
            try {
                fs::create_directories(outputDir);
                std::cout << Color::CYAN << "[Info] Created output directory: "
                    << outputDir.string() << Color::RESET << "\n";
            }
            catch (const std::exception& e) {
                std::cerr << Color::RED << "[Error] Failed to create output dir: "
                    << e.what() << Color::RESET << "\n";
            }
        }

        // 回傳標準化的字串 (給 STB Image 用)
        return fullPath.string();
    }

    int RunTestBootstrap(const std::string& suiteName, TestEntryFunc testFunc) {

        // 1. 路徑計算 (因為上面 #ifndef 擋住了，這裡一定安全)
        fs::path projectRoot = PROJECT_ROOT;

        // 硬編碼的測試資料路徑 (如果這也是變動的，未來也可以移到 props)
        fs::path dataFolder = "05_QA_Validation/feasibility_test_data";
        fs::path imagePath = "20250117 L5C/Envision/Low_Angle_by_nor_line/mura/cal_25-11-17_11-16-48-283.bmp";
        fs::path fullPath = projectRoot / dataFolder / imagePath;

        fullPath.make_preferred();

        // 2. 安全檢查
        if (!fs::exists(fullPath)) {
            std::cerr << Color::RED << "[Error] Cannot find test image!" << Color::RESET << "\n";
            std::cerr << Color::RED << "Looking at: " << fullPath << Color::RESET << "\n";
            std::cerr << "Root: " << projectRoot << "\n";
            // 這裡可以選擇不暫停直接 return，方便自動化測試
            std::cout << "Press Enter to exit.\n";
            std::cin.get();
            return -1;
        }

        std::string testFullPath = fullPath.string();

        // 3. 顯示歡迎訊息
        std::cout << Color::YELLOW << "Starting " << suiteName << "..." << Color::RESET << "\n";
        std::cout << Color::YELLOW << "Target Image: " << imagePath.filename().string() << Color::RESET << "\n";
        std::cout << "--------------------------------------------------\n";

        // 4. 執行傳入的測試函式
        try {
            testFunc(testFullPath);
        }
        catch (const std::exception& e) {
            std::cerr << Color::RED << "\n[Fatal Error] Test crashed: " << e.what() << Color::RESET << "\n";
            return -1;
        }

        // 5. 結束 (在 CI 環境或批次執行時，這裡可以考慮移除暫停)
        std::cout << "\n" << Color::GREEN << "Test Finished. Press Enter to exit." << Color::RESET << "\n";
        std::cin.get();
        return 0;
    }

}  // namespace framework
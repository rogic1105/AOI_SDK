#include "framework/test_utils.hpp"  // 自己的標頭檔排第一

#include <filesystem>
#include <iostream>
#include <string>

// 專案內的相依標頭檔
#include "cpp_utils/terminal_colors.hpp"

// 注意：這裡不需要 include stb_image.h，因為此函式只處理路徑，
// 實際的讀圖動作是在 callback (testFunc) 裡面進行的。

namespace fs = std::filesystem;

namespace framework {

    int RunTestBootstrap(const std::string& suiteName, TestEntryFunc testFunc) {
        // 1. 路徑計算邏輯 (集中管理)
#ifdef WORKSPACE_ROOT
        fs::path workSpaceRoot = WORKSPACE_ROOT;
#else
    // 防呆：如果沒設定 props，預設回退路徑
        fs::path workSpaceRoot = "../../../..";
#endif

        // 硬編碼的測試資料路徑
        fs::path dataFolder = "02_Projects_Active/PICoater/05_QA_Validation/feasibility_test_data";
        fs::path imagePath = "20250117 L5C/Envision/Low_Angle_by_nor_line/mura/cal_25-11-17_11-16-48-283.bmp";
        fs::path fullPath = workSpaceRoot / dataFolder / imagePath;

        // 標準化路徑分隔符號
        fullPath.make_preferred();

        // 2. 安全檢查
        if (!fs::exists(fullPath)) {
            std::cerr << Color::RED << "[Error] Cannot find test image!" << Color::RESET << "\n";
            std::cerr << Color::RED << "Looking at: " << fullPath << Color::RESET << "\n";
            std::cerr << "Root: " << workSpaceRoot << "\n";
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

        // 5. 結束暫停
        std::cout << "\n" << Color::GREEN << "Press Enter to exit." << Color::RESET << "\n";
        std::cin.get();
        return 0;
    }

}  // namespace framework
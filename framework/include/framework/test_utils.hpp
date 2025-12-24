#pragma once

#include <functional>
#include <string>

namespace framework {

	// 定義測試函式的標準簽名：接受一個圖片路徑，回傳 void
	using TestEntryFunc = std::function<void(const std::string&)>;

	// 通用的測試啟動器
	// suiteName: 測試套件名稱 (顯示用)
	// testFunc:  要執行的測試邏輯 (RunCoreTests 或 RunModuleTests)
	// 回傳值: 程式執行結果代碼 (0 為成功)
	int RunTestBootstrap(const std::string& suiteName, TestEntryFunc testFunc);

}  // namespace framework
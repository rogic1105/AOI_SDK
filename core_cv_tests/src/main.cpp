// core_cv_tests/main.cpp

#include "framework/test_utils.hpp" // 包含 RunTestBootstrap
// 宣告你的測試進入點
void RunCoreTests(const std::string& imgPath);

int main() {
    // 一行搞定，把 "RunCoreTests" 函式傳進去
    return framework::RunTestBootstrap("AOI Core SDK Tests", RunCoreTests);
}
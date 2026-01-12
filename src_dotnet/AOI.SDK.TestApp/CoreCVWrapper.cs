// AOI_SDK\src_dotnet\AOI.SDK.TestApp\CoreCVWrapper.cs

using System;
using System.Runtime.InteropServices;

namespace AOI.SDK.TestApp
{
    /// <summary>
    /// 封裝 core_cv_api.dll 的原生函式庫
    /// </summary>
    public static class CoreCVWrapper
    {
        private const string DLL_NAME = "core_cv_api.dll";

        // =========================================================
        // 1. 記憶體管理 (Pinned Memory) - 用於極速 IO
        // =========================================================
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr CoreCV_AllocPinned(ulong size);

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern void CoreCV_FreePinned(IntPtr ptr);

        // =========================================================
        // 2. 極速 IO (Fast IO) - 繞過 GDI+ 直接讀寫 BMP
        // =========================================================
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)] // C++ bool 轉 C# bool
        public static extern bool CoreCV_FastReadBMP(string filepath, out int w, out int h, IntPtr outBuffer, int bufferSize);

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        [return: MarshalAs(UnmanagedType.I1)]
        public static extern bool CoreCV_FastWriteBMP(string filepath, int w, int h, IntPtr inBuffer);

        // =========================================================
        // 3. 影像處理演算法
        // =========================================================

        // 亮度調整
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Brighten(IntPtr src, int width, int height, int value, IntPtr dst);

        // 二值化
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Threshold(IntPtr src, int width, int height, byte threshold, IntPtr dst);

        // 反轉
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Invert(IntPtr src, int width, int height, IntPtr dst);

        // 卷積 (預留)
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Convolution(IntPtr src, int width, int height, IntPtr mask, int maskSize, IntPtr dst);
    }
}
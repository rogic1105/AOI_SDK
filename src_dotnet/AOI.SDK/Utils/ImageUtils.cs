using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace AOI.SDK.Utils
{
    public static class ImageUtils
    {
        // [新增] 靜態快取灰階調色盤，避免重複建立物件，提升效能
        public static readonly ColorPalette GrayScalePalette;

        static ImageUtils()
        {
            // 透過一個暫時的 Bitmap 取得標準 Palette 結構
            using (var tempBmp = new Bitmap(1, 1, PixelFormat.Format8bppIndexed))
            {
                GrayScalePalette = tempBmp.Palette;
            }

            // 填入 0-255 灰階值
            for (int i = 0; i < 256; i++)
            {
                GrayScalePalette.Entries[i] = Color.FromArgb(i, i, i);
            }
        }

        /// <summary>
        /// 將 byte[] 資料轉為 8bpp Bitmap
        /// </summary>
        public static Bitmap Create8bppBitmap(byte[] data, int width, int height)
        {
            if (width <= 0 || height <= 0 || data == null) return null;

            // 鎖定 byte[] 取得指標，呼叫 IntPtr 版本以共用邏輯
            GCHandle handle = GCHandle.Alloc(data, GCHandleType.Pinned);
            try
            {
                return Create8bppBitmap(handle.AddrOfPinnedObject(), width, height);
            }
            finally
            {
                handle.Free();
            }
        }

        /// <summary>
        /// [新增] 將 IntPtr (Unmanaged Memory) 資料轉為 8bpp Bitmap
        /// 專為 Fast IO 與 Pinned Memory 設計，避免額外的 Array Copy
        /// </summary>
        public static Bitmap Create8bppBitmap(IntPtr srcPtr, int width, int height)
        {
            if (width <= 0 || height <= 0 || srcPtr == IntPtr.Zero) return null;

            Bitmap bmp = new Bitmap(width, height, PixelFormat.Format8bppIndexed);

            // 直接指定快取好的 Palette
            bmp.Palette = GrayScalePalette;

            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, width, height),
                ImageLockMode.WriteOnly, PixelFormat.Format8bppIndexed);

            try
            {
                unsafe
                {
                    // 使用 Buffer.MemoryCopy 進行快速區塊複製
                    // 注意：這裡假設 Stride == Width，這在 8bpp 且寬度為 4 的倍數時通常成立
                    // 若寬度非 4 的倍數，BMP會有 Padding，需改用逐行複製
                    long bufferSize = bData.Stride * height;

                    if (bData.Stride == width)
                    {
                        Buffer.MemoryCopy((void*)srcPtr, (void*)bData.Scan0, bufferSize, bufferSize);
                    }
                    else
                    {
                        // 處理 Stride Padding (逐行複製)
                        byte* pSrc = (byte*)srcPtr;
                        byte* pDst = (byte*)bData.Scan0;
                        for (int y = 0; y < height; y++)
                        {
                            Buffer.MemoryCopy(pSrc + y * width, pDst + y * bData.Stride, width, width);
                        }
                    }
                }
            }
            finally
            {
                bmp.UnlockBits(bData);
            }

            return bmp;
        }

        public static byte[] BitmapTo8bppArray(Bitmap src, out int w, out int h)
        {
            w = src.Width;
            h = src.Height;
            byte[] result = new byte[w * h];

            using (Bitmap bmp24 = new Bitmap(w, h, PixelFormat.Format24bppRgb))
            {
                using (Graphics g = Graphics.FromImage(bmp24))
                {
                    g.DrawImage(src, 0, 0, w, h);
                }

                BitmapData bData = bmp24.LockBits(new Rectangle(0, 0, w, h),
                    ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);

                int stride = bData.Stride;
                int byteCount = stride * h;
                byte[] rgbData = new byte[byteCount];
                Marshal.Copy(bData.Scan0, rgbData, 0, byteCount);
                bmp24.UnlockBits(bData);

                int width = w;
                Parallel.For(0, h, y =>
                {
                    int rowStart = y * stride;
                    int outRowStart = y * width;
                    for (int x = 0; x < width; x++)
                    {
                        int idx = rowStart + x * 3;
                        byte B = rgbData[idx];
                        byte G = rgbData[idx + 1];
                        byte R = rgbData[idx + 2];
                        result[outRowStart + x] = (byte)((R * 0.299) + (G * 0.587) + (B * 0.114));
                    }
                });
            }
            return result;
        }
    }
}
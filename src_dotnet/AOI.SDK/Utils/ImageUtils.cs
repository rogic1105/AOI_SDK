// AOI_SDK\src_dotnet\AOI.SDK\Utils\ImageUtils.cs

using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace AOI.SDK.Utils
{
    public static class ImageUtils
    {
        /// <summary>
        /// 將 byte[] 資料轉為 8bpp Bitmap
        /// </summary>
        public static Bitmap Create8bppBitmap(byte[] data, int width, int height)
        {
            if (width <= 0 || height <= 0 || data == null) return null;

            Bitmap bmp = new Bitmap(width, height, PixelFormat.Format8bppIndexed);

            // 設定灰階調色盤
            ColorPalette pal = bmp.Palette;
            for (int i = 0; i < 256; i++) pal.Entries[i] = Color.FromArgb(i, i, i);
            bmp.Palette = pal;

            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, width, height),
                ImageLockMode.WriteOnly, PixelFormat.Format8bppIndexed);

            try
            {
                if (bData.Stride == width)
                {
                    Marshal.Copy(data, 0, bData.Scan0, data.Length);
                }
                else
                {
                    for (int y = 0; y < height; y++)
                    {
                        Marshal.Copy(data, y * width, bData.Scan0 + y * bData.Stride, width);
                    }
                }
            }
            finally
            {
                bmp.UnlockBits(bData);
            }

            return bmp;
        }

        // ConvertTo8bppArray 這個方法目前你在 FastRead 之後其實用不太到了
        // 但如果未來要支援開啟 JPG/PNG，還是可以保留
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
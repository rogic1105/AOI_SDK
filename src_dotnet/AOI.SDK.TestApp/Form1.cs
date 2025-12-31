using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using AOI.SDK.UI; 

namespace AOI.SDK.TestApp
{
    public partial class Form1 : Form
    {
        // ---------------------------------------------------------
        // 1. DLL 匯入 (對應 core_cv_api 的 export_api.cpp)
        // ---------------------------------------------------------

        // [修正] DLL 名稱改為我們剛編譯出來的檔案
        private const string DLL_NAME = "core_cv_api.dll";

        // [修正] 參數順序與 C++ 標頭檔保持一致: (src, w, h, val, dst)
        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Brighten(IntPtr src, int width, int height, int value, IntPtr dst);

        [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        public static extern int CoreCV_Threshold(IntPtr src, int width, int height, byte threshold, IntPtr dst);

        // 這次範例先沒加 Invert，你可以自己擴充 Convolution
        // [DllImport(DLL_NAME, CallingConvention = CallingConvention.Cdecl)]
        // public static extern int CoreCV_Convolution(IntPtr src, int width, int height, float[] mask, int maskSize, IntPtr dst);

        // ---------------------------------------------------------
        // 2. 變數宣告
        // ---------------------------------------------------------
        private byte[] _originalData; // 原始圖片數據 (8bpp)
        private byte[] _currentData;  // 目前顯示的圖片數據
        private int _imgW, _imgH;

        public Form1()
        {
            InitializeComponent();

            // 綁定 SmartCanvas 的滑鼠事件
            canvasMain.PixelHovered += (x, y, color) =>
            {
                // 顯示座標與灰階值
                if (x >= 0 && x < _imgW && y >= 0 && y < _imgH)
                {
                    lblPixelInfo.Text = $"座標: ({x}, {y}) | 亮度: {color.R}";
                }
            };
        }

        // ---------------------------------------------------------
        // 3. 讀取圖片
        // ---------------------------------------------------------
        private void btnLoad_Click(object sender, EventArgs e)
        {
            OpenFileDialog ofd = new OpenFileDialog();
            ofd.Filter = "Image Files|*.bmp;*.png;*.jpg;*.tif";

            if (ofd.ShowDialog() == DialogResult.OK)
            {
                using (Bitmap bmp = new Bitmap(ofd.FileName))
                {
                    // 強制轉為 8bpp 灰階
                    _originalData = ConvertTo8bppArray(bmp, out _imgW, out _imgH);

                    // 初始化目前數據
                    _currentData = new byte[_originalData.Length];
                    Array.Copy(_originalData, _currentData, _originalData.Length);

                    // 顯示圖片
                    ShowImage(_currentData);

                    // 自動縮放
                    canvasMain.FitToScreen();
                }
            }
        }

        // ---------------------------------------------------------
        // 4. 功能按鈕
        // ---------------------------------------------------------

        // 二值化
        private void btnBinary_Click(object sender, EventArgs e)
        {
            // 注意參數轉型: numThreshold.Value 是 decimal，要轉 byte
            RunProcess((src, dst, w, h) =>
                CoreCV_Threshold(src, w, h, (byte)numThreshold.Value, dst)
            );
        }

        // 變亮
        private void btnBrighten_Click(object sender, EventArgs e)
        {
            RunProcess((src, dst, w, h) =>
                CoreCV_Brighten(src, w, h, (int)numBrightVal.Value, dst)
            );
        }

        // 反轉 (假設你還沒實作 CoreCV_Invert，這裡先註解掉或改用 CPU 實作)
        private void btnInvert_Click(object sender, EventArgs e)
        {
            MessageBox.Show("C++ DLL 尚未實作 Invert，請先實作 export_api.cpp");
            /*
            RunProcess((src, dst, w, h) =>
                CoreCV_Invert(src, w, h, dst)
            );
            */
        }

        // 回到原圖
        private void btnReset_Click(object sender, EventArgs e)
        {
            if (_originalData == null) return;
            Array.Copy(_originalData, _currentData, _originalData.Length);
            ShowImage(_currentData);
        }

        // ---------------------------------------------------------
        // 5. 核心處理邏輯 (包裝指針操作)
        // ---------------------------------------------------------

        // 定義委派
        delegate int DllFunc(IntPtr src, IntPtr dst, int w, int h);

        private void RunProcess(DllFunc func)
        {
            if (_originalData == null) { MessageBox.Show("請先讀取圖片"); return; }

            // 鎖定記憶體位置，避免 GC 移動
            GCHandle hSrc = GCHandle.Alloc(_currentData, GCHandleType.Pinned);
            // 這裡直接原地修改 (In-place)，所以 Src 和 Dst 指向同一塊記憶體
            // 如果你的演算法不支援原地修改，你需要 new 一個新的 byte[] 給 hDst
            GCHandle hDst = GCHandle.Alloc(_currentData, GCHandleType.Pinned);

            try
            {
                IntPtr ptrSrc = hSrc.AddrOfPinnedObject();
                IntPtr ptrDst = hDst.AddrOfPinnedObject();

                // 呼叫 C++
                // 注意：這裡我為了配合你的 RunProcess 簽章，維持 func(src, dst, w, h)
                // 但實際執行的是上面 Lambda 表達式裡面的 CoreCV_xxx(src, w, h, val, dst)
                int ret = func(ptrSrc, ptrDst, _imgW, _imgH);

                if (ret == 0)
                {
                    ShowImage(_currentData);
                }
                else
                {
                    MessageBox.Show($"DLL 執行錯誤，代碼: {ret}\n(可能原因: CUDA 錯誤或參數錯誤)");
                }
            }
            catch (DllNotFoundException dllEx)
            {
                MessageBox.Show($"找不到 {DLL_NAME}！\n請確認編譯輸出路徑是否正確。\n" + dllEx.Message);
            }
            catch (Exception ex)
            {
                MessageBox.Show("發生錯誤: " + ex.Message);
            }
            finally
            {
                if (hSrc.IsAllocated) hSrc.Free();
                if (hDst.IsAllocated) hDst.Free();
            }
        }

        // ---------------------------------------------------------
        // 顯示與轉檔輔助 (不變)
        // ---------------------------------------------------------
        private void ShowImage(byte[] data)
        {
            if (_imgW <= 0 || _imgH <= 0) return;

            Bitmap bmp = new Bitmap(_imgW, _imgH, PixelFormat.Format8bppIndexed);
            ColorPalette pal = bmp.Palette;
            for (int i = 0; i < 256; i++) pal.Entries[i] = Color.FromArgb(i, i, i);
            bmp.Palette = pal;

            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, _imgW, _imgH),
                ImageLockMode.WriteOnly, PixelFormat.Format8bppIndexed);

            // 如果 Stride == Width，可以直接 Marshal.Copy
            // 但為了保險起見，還是逐行複製比較穩
            for (int y = 0; y < _imgH; y++)
            {
                Marshal.Copy(data, y * _imgW, bData.Scan0 + y * bData.Stride, _imgW);
            }

            bmp.UnlockBits(bData);
            canvasMain.Image = bmp;
        }

        private byte[] ConvertTo8bppArray(Bitmap src, out int w, out int h)
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
                byte[] rgbData = new byte[stride * h];
                Marshal.Copy(bData.Scan0, rgbData, 0, rgbData.Length);
                bmp24.UnlockBits(bData);

                // [修正] 複製 out 參數到區域變數，給 Lambda 使用
                int width = w;

                // RGB -> Gray (平行化加速讀取)
                System.Threading.Tasks.Parallel.For(0, h, y =>
                {
                    // 這裡要把 x < w 改成 x < width
                    for (int x = 0; x < width; x++)
                    {
                        int idx = y * stride + x * 3;
                        byte B = rgbData[idx];
                        byte G = rgbData[idx + 1];
                        byte R = rgbData[idx + 2];
                        result[y * width + x] = (byte)((R * 0.299) + (G * 0.587) + (B * 0.114));
                    }
                });
            }
            return result;
        }
    }
}
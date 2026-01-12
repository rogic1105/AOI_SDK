// AOI_SDK\src_dotnet\AOI.SDK.TestApp\Form1.cs

using AOI.SDK.UI;
using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks; // 用於 Parallel
using System.Windows.Forms;

namespace AOI.SDK.TestApp
{
    public partial class Form1 : Form
    {
        // ---------------------------------------------------------
        // 變數宣告
        // ---------------------------------------------------------
        private byte[] _originalData; // 原始圖片數據 (8bpp)
        private byte[] _currentData;  // 目前顯示的圖片數據 (同時作為 Src 和 Dst)
        private int _imgW, _imgH;

        public Form1()
        {
            InitializeComponent();

            // 綁定 SmartCanvas 的滑鼠事件
            canvasMain.PixelHovered += (x, y, color) =>
            {
                if (x >= 0 && x < _imgW && y >= 0 && y < _imgH)
                {
                    lblPixelInfo.Text = $"座標: ({x}, {y}) | 亮度: {color.R}";
                }
            };
        }

        // ---------------------------------------------------------
        // 3. 極速讀取圖片 (Fast IO)
        // ---------------------------------------------------------
        private void btnLoad_Click(object sender, EventArgs e)
        {
            OpenFileDialog ofd = new OpenFileDialog();
            ofd.Filter = "BMP Files|*.bmp|All Files|*.*";

            if (ofd.ShowDialog() == DialogResult.OK)
            {
                int maxW = 16384;
                int maxH = 10000;
                ulong maxBytes = (ulong)(maxW * maxH);

                IntPtr pBuffer = CoreCVWrapper.CoreCV_AllocPinned(maxBytes);

                try
                {
                    int w, h;
                    bool success = CoreCVWrapper.CoreCV_FastReadBMP(ofd.FileName, out w, out h, pBuffer, (int)maxBytes);

                    if (success)
                    {
                        _imgW = w;
                        _imgH = h;
                        int realSize = w * h;

                        _originalData = new byte[realSize];
                        Marshal.Copy(pBuffer, _originalData, 0, realSize);

                        _currentData = new byte[realSize];
                        Array.Copy(_originalData, _currentData, realSize);

                        ShowImage(_currentData);
                        canvasMain.FitToScreen();

                        // [修改] 更新 TextBox 而不是 Label
                        txtLoadPath.Text = ofd.FileName;
                        // 讀取新的圖時，清空 Save Path，避免誤會
                        txtSavePath.Text = "";
                    }
                    else
                    {
                        MessageBox.Show("FastRead 失敗！");
                    }
                }
                catch (Exception ex)
                {
                    MessageBox.Show("發生錯誤: " + ex.Message);
                }
                finally
                {
                    CoreCVWrapper.CoreCV_FreePinned(pBuffer);
                }
            }
        }

        // 極速存檔
        private void btnSave_Click(object sender, EventArgs e)
        {
            if (_currentData == null) { MessageBox.Show("沒有圖片可存！"); return; }

            SaveFileDialog sfd = new SaveFileDialog();
            sfd.Filter = "BMP Files|*.bmp";
            sfd.FileName = "output_fast.bmp";

            if (sfd.ShowDialog() == DialogResult.OK)
            {
                GCHandle hData = GCHandle.Alloc(_currentData, GCHandleType.Pinned);
                try
                {
                    IntPtr ptrData = hData.AddrOfPinnedObject();
                    bool success = CoreCVWrapper.CoreCV_FastWriteBMP(sfd.FileName, _imgW, _imgH, ptrData);

                    if (success)
                    {
                        MessageBox.Show("存檔成功！");
                        // [修改] 更新 TextBox
                        txtSavePath.Text = sfd.FileName;
                    }
                    else
                    {
                        MessageBox.Show("存檔失敗！");
                    }
                }
                finally
                {
                    hData.Free();
                }
            }
        }
        private void btnReset_Click(object sender, EventArgs e)
        {
            if (_originalData == null) return;
            Array.Copy(_originalData, _currentData, _originalData.Length);
            ShowImage(_currentData);
        }

        private void btnOpenLoadDir_Click(object sender, EventArgs e)
        {
            OpenFolder(txtLoadPath.Text);
        }

        private void btnOpenSaveDir_Click(object sender, EventArgs e)
        {
            OpenFolder(txtSavePath.Text);
        }

        private void OpenFolder(string filePath)
        {
            if (string.IsNullOrEmpty(filePath)) return;

            try
            {
                if (File.Exists(filePath))
                {
                    // 如果檔案存在，開啟資料夾並選取該檔案 (/select)
                    Process.Start("explorer.exe", "/select,\"" + filePath + "\"");
                }
                else
                {
                    // 如果檔案不存在但路徑有文字，嘗試開啟其所在的資料夾
                    string dir = Path.GetDirectoryName(filePath);
                    if (Directory.Exists(dir))
                    {
                        Process.Start("explorer.exe", "\"" + dir + "\"");
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("無法開啟資料夾: " + ex.Message);
            }
        }



        // ---------------------------------------------------------
        // 功能按鈕
        // ---------------------------------------------------------
        private void btnBinary_Click(object sender, EventArgs e)
        {
            RunProcess((src, dst, w, h) =>
                CoreCVWrapper.CoreCV_Threshold(src, w, h, (byte)numThreshold.Value, dst)
            );
        }

        private void btnBrighten_Click(object sender, EventArgs e)
        {
            RunProcess((src, dst, w, h) =>
                CoreCVWrapper.CoreCV_Brighten(src, w, h, (int)numBrightVal.Value, dst)
            );
        }

        private void btnInvert_Click(object sender, EventArgs e)
        {
            RunProcess((src, dst, w, h) =>
                CoreCVWrapper.CoreCV_Invert(src, w, h, dst)
            );
        }

        private void btnConvolution_Click(object sender, EventArgs e)
        {
            // 定義一個 3x3 銳化 (Sharpen) 遮罩
            float[] mask = {
                 0, -1,  0,
                -1,  5, -1,
                 0, -1,  0
            };

            // 鎖定 Mask 記憶體
            GCHandle hMask = GCHandle.Alloc(mask, GCHandleType.Pinned);

            try
            {
                IntPtr ptrMask = hMask.AddrOfPinnedObject();

                // 呼叫 Wrapper
                RunProcess((src, dst, w, h) =>
                    CoreCVWrapper.CoreCV_Convolution(src, w, h, ptrMask, 3, dst)
                );
            }
            finally
            {
                hMask.Free();
            }
        }

        // ---------------------------------------------------------
        // 核心處理邏輯 (In-Place 處理)
        // ---------------------------------------------------------
        delegate int DllFunc(IntPtr src, IntPtr dst, int w, int h);

        private void RunProcess(DllFunc func)
        {
            if (_originalData == null || _currentData == null)
            {
                MessageBox.Show("請先讀取圖片");
                return;
            }

            // 因為我們是 In-Place 修改 (Src = Dst = _currentData)，只需要鎖定一個陣列
            GCHandle hData = GCHandle.Alloc(_currentData, GCHandleType.Pinned);

            try
            {
                IntPtr ptrData = hData.AddrOfPinnedObject();

                // 呼叫 Wrapper
                // 因為是原地修改，Src 和 Dst 傳同一個指標
                int ret = func(ptrData, ptrData, _imgW, _imgH);

                if (ret == 0) // CORE_CV_SUCCESS
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
                MessageBox.Show($"找不到 core_cv_api.dll！\n請確認編譯輸出路徑是否正確。\n{dllEx.Message}");
            }
            catch (Exception ex)
            {
                MessageBox.Show("發生錯誤: " + ex.Message);
            }
            finally
            {
                if (hData.IsAllocated) hData.Free();
            }
        }


        // ---------------------------------------------------------
        // 顯示與轉檔輔助
        // ---------------------------------------------------------
        private void ShowImage(byte[] data)
        {
            if (_imgW <= 0 || _imgH <= 0) return;

            // 建立 8bpp Bitmap 供顯示
            Bitmap bmp = new Bitmap(_imgW, _imgH, PixelFormat.Format8bppIndexed);

            // 設定調色盤
            ColorPalette pal = bmp.Palette;
            for (int i = 0; i < 256; i++) pal.Entries[i] = Color.FromArgb(i, i, i);
            bmp.Palette = pal;

            // 拷貝數據
            BitmapData bData = bmp.LockBits(new Rectangle(0, 0, _imgW, _imgH),
                ImageLockMode.WriteOnly, PixelFormat.Format8bppIndexed);

            try
            {
                // 若 Stride 等於寬度，可一次拷貝 (通常 8bpp 且寬度是 4 的倍數時)
                if (bData.Stride == _imgW)
                {
                    Marshal.Copy(data, 0, bData.Scan0, data.Length);
                }
                else
                {
                    // 否則逐行拷貝
                    for (int y = 0; y < _imgH; y++)
                    {
                        Marshal.Copy(data, y * _imgW, bData.Scan0 + y * bData.Stride, _imgW);
                    }
                }
            }
            finally
            {
                bmp.UnlockBits(bData);
            }

            // 賦值給 SmartCanvas
            // 注意：SmartCanvas 內部應該要 Dispose 舊圖，或者這裡手動 Dispose 舊的
            var oldImg = canvasMain.Image;
            canvasMain.Image = bmp;
            if (oldImg != null) oldImg.Dispose();
        }



    }
}
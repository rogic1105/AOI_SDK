using System;
using System.Drawing;
using System.Windows.Forms;
using Matrox.MatroxImagingLibrary;

namespace AOI.SDK.UI
{
    // 事件參數：回傳像素座標與數值
    public class PixelInfoArgs : EventArgs
    {
        public int ImageX { get; set; }
        public int ImageY { get; set; }
        public double Value { get; set; }
        public double ZoomFactor { get; set; }
    }

    public class SmartCanvasPanel : Panel
    {
        private MIL_ID _milSystem = MIL.M_NULL;
        private MIL_ID _milDisplay = MIL.M_NULL;
        private MIL_ID _currentImage = MIL.M_NULL;

        // 顯示狀態變數
        private double _zoomFactor = 1.0;
        private double _panOffsetX = 0.0;
        private double _panOffsetY = 0.0;

        // 滑鼠互動變數
        private bool _isDragging = false;
        private int _lastMouseX;
        private int _lastMouseY;

        // 影像資訊
        private MIL_INT _imageSizeX = 0;
        private MIL_INT _imageSizeY = 0;

        public event EventHandler<PixelInfoArgs> PixelInfoChanged;

        public SmartCanvasPanel()
        {
            this.BackColor = Color.Black;

            // 【關鍵 1】設定控制項樣式，禁止 GDI+ 重繪背景
            // 這是解決縮放時產生「黑白殘影」的核心
            this.SetStyle(ControlStyles.Opaque, true);
            this.SetStyle(ControlStyles.UserPaint, true);
            this.SetStyle(ControlStyles.AllPaintingInWmPaint, true);
            this.DoubleBuffered = false; // Overlay 不需要 DoubleBuffer，開了反而會擋住
        }

        // 【關鍵 2】覆寫背景繪製，什麼都不做
        // 讓 MIL 的 Overlay 層全權負責顯示，防止 C# 刷掉畫面
        protected override void OnPaintBackground(PaintEventArgs e)
        {
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            // 如果需要畫十字線或文字，可以在這裡用 e.Graphics 畫 (會疊在 MIL 影像上)
            // base.OnPaint(e); 
        }

        /// <summary>
        /// 綁定 MIL 影像到此 Panel
        /// </summary>
        public void AttachImage(MIL_ID milSystem, MIL_ID milImage)
        {
            // 清理舊資源
            FreeResources();

            _milSystem = milSystem;
            _currentImage = milImage;

            if (_milSystem == MIL.M_NULL || _currentImage == MIL.M_NULL) return;

            // 強制建立 Handle，防止 MIL 彈出新視窗
            if (!this.IsHandleCreated) this.CreateControl();

            // 取得影像尺寸
            MIL.MbufInquire(_currentImage, MIL.M_SIZE_X, ref _imageSizeX);
            MIL.MbufInquire(_currentImage, MIL.M_SIZE_Y, ref _imageSizeY);

            // 分配 Display (M_DEFAULT 通常對應 Overlay)
            MIL.MdispAlloc(_milSystem, MIL.M_DEFAULT, "M_DEFAULT", MIL.M_DEFAULT, ref _milDisplay);

            // 【關鍵 3】原子綁定：Display + Image + Window Handle
            MIL.MdispSelectWindow(_milDisplay, _currentImage, this.Handle);

            // 初始適配視窗
            FitToScreen();
        }

        /// <summary>
        /// 計算縮放與平移，使影像適配視窗大小並置中
        /// </summary>
        public void FitToScreen()
        {
            if (_imageSizeX == 0 || _imageSizeY == 0) return;

            // 1. 計算縮放比例 (留 5% 邊距)
            double ratioW = (double)this.Width / _imageSizeX;
            double ratioH = (double)this.Height / _imageSizeY;
            _zoomFactor = Math.Min(ratioW, ratioH) * 0.95;

            // 2. 計算置中 Offset
            // 公式：Offset = (ImageCenter) - (WindowCenter / Zoom)
            // MIL 的 Pan Offset 定義為「視窗左上角(0,0) 對應到的圖片座標」
            _panOffsetX = (_imageSizeX / 2.0) - (this.Width / (2.0 * _zoomFactor));
            _panOffsetY = (_imageSizeY / 2.0) - (this.Height / (2.0 * _zoomFactor));

            ApplyDisplaySettings();
        }

        public void FreeResources()
        {
            if (_milDisplay != MIL.M_NULL)
            {
                MIL.MdispFree(_milDisplay);
                _milDisplay = MIL.M_NULL;
            }
            _currentImage = MIL.M_NULL;
        }

        protected override void OnHandleDestroyed(EventArgs e)
        {
            FreeResources();
            base.OnHandleDestroyed(e);
        }

        // =========================================================================
        // 滑鼠操作 (手動計算 MIL Pan/Zoom)
        // =========================================================================
        protected override void OnMouseDown(MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left)
            {
                _isDragging = true;
                _lastMouseX = e.X;
                _lastMouseY = e.Y;
                this.Cursor = Cursors.Hand;
            }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            _isDragging = false;
            this.Cursor = Cursors.Default;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            // 1. 平移 (Pan)
            if (_isDragging && _milDisplay != MIL.M_NULL)
            {
                int deltaX = e.X - _lastMouseX;
                int deltaY = e.Y - _lastMouseY;

                // 往右拉(delta>0) = 視窗往左看 = Offset 減少
                _panOffsetX -= (deltaX / _zoomFactor);
                _panOffsetY -= (deltaY / _zoomFactor);

                _lastMouseX = e.X;
                _lastMouseY = e.Y;

                ApplyDisplaySettings();
            }

            // 2. 數值顯示 (Pixel Peeking)
            if (_currentImage != MIL.M_NULL)
            {
                // 計算滑鼠下的影像座標
                double imgX = _panOffsetX + (e.X / _zoomFactor);
                double imgY = _panOffsetY + (e.Y / _zoomFactor);
                int iX = (int)imgX;
                int iY = (int)imgY;

                // 邊界檢查
                if (iX >= 0 && iX < _imageSizeX && iY >= 0 && iY < _imageSizeY)
                {
                    byte[] val = new byte[1];
                    // 這裡使用 try-catch 防止極端縮放時的邊界誤差
                    try { MIL.MbufGet2d(_currentImage, iX, iY, 1, 1, val); } catch { val[0] = 0; }

                    PixelInfoChanged?.Invoke(this, new PixelInfoArgs
                    {
                        ImageX = iX,
                        ImageY = iY,
                        Value = val[0],
                        ZoomFactor = _zoomFactor
                    });
                }
            }
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            double oldZoom = _zoomFactor;
            // 滾輪縮放邏輯
            double scaleChange = (e.Delta > 0) ? 1.25 : 0.8;
            double newZoom = oldZoom * scaleChange;

            // 限制範圍
            if (newZoom < 0.001) newZoom = 0.001;
            if (newZoom > 500.0) newZoom = 500.0;

            // 以滑鼠為中心縮放 (CAD Style Zoom)
            // 原理：滑鼠指向的那個像素點，在縮放前後應該保持在螢幕上的同一個位置
            double mouseX = e.X;
            double mouseY = e.Y;

            _panOffsetX = _panOffsetX + mouseX * (1.0 / oldZoom - 1.0 / newZoom);
            _panOffsetY = _panOffsetY + mouseY * (1.0 / oldZoom - 1.0 / newZoom);

            _zoomFactor = newZoom;
            ApplyDisplaySettings();
        }

        private void ApplyDisplaySettings()
        {
            if (_milDisplay == MIL.M_NULL) return;

            try
            {
                // 使用最基礎的 Zoom 和 Pan 指令，這些一定被 Overlay 支援
                // 這樣就避開了 "Control type not supported" 的錯誤
                MIL.MdispControl(_milDisplay, MIL.M_ZOOM_FACTOR_X, _zoomFactor);
                MIL.MdispControl(_milDisplay, MIL.M_ZOOM_FACTOR_Y, _zoomFactor);
                MIL.MdispControl(_milDisplay, MIL.M_PAN_OFFSET_X, _panOffsetX);
                MIL.MdispControl(_milDisplay, MIL.M_PAN_OFFSET_Y, _panOffsetY);
            }
            catch
            {
                // 忽略錯誤
            }
        }

        // 視窗大小改變時，Overlay 會自動跟隨 Handle，不需要額外重繪
        protected override void OnResize(EventArgs eventargs)
        {
            base.OnResize(eventargs);
        }
    }
}
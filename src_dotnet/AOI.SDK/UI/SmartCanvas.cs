// AOI_SDK\src_dotnet\AOI.SDK.UI\SmartCanvas.cs

using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace AOI.SDK.UI
{
    public class CanvasInfo
    {
        public int ImageX { get; set; }
        public int ImageY { get; set; }
        public Color PixelColor { get; set; }
        public float Zoom { get; set; }
        public PointF PanOffset { get; set; }
    }

    public class SmartCanvas : PictureBox
    {
        private float _zoom = 1.0f;
        private PointF _panOffset = PointF.Empty;
        private bool _isDragging = false;
        private Point _lastMousePos;

        private int _lastImgX = 0;
        private int _lastImgY = 0;
        private Color _lastColor = Color.Black;

        public event Action<CanvasInfo> StatusChanged;

        public float Zoom => _zoom;
        public PointF PanOffset => _panOffset;

        public Action<object, object, object> PixelHovered { get; set; }

        public SmartCanvas()
        {
            this.DoubleBuffered = true;
            this.SizeMode = PictureBoxSizeMode.Normal;
            this.Cursor = Cursors.Cross;
            this.BackColor = Color.Black;
        }

        private void TriggerStatusChange()
        {
            StatusChanged?.Invoke(new CanvasInfo
            {
                ImageX = _lastImgX,
                ImageY = _lastImgY,
                PixelColor = _lastColor,
                Zoom = _zoom,
                PanOffset = _panOffset
            });
        }

        // [新增] 設定視圖 (用於還原上一次的縮放與平移)
        public void SetView(float zoom, PointF panOffset)
        {
            _zoom = zoom;
            _panOffset = panOffset;
            this.Invalidate();
            TriggerStatusChange(); // 更新外部狀態列
        }

        public void FitToScreen()
        {
            if (this.Image == null) return;

            float ratioW = (float)this.Width / this.Image.Width;
            float ratioH = (float)this.Height / this.Image.Height;
            _zoom = Math.Min(ratioW, ratioH) * 0.95f;

            float drawW = this.Image.Width * _zoom;
            float drawH = this.Image.Height * _zoom;
            _panOffset = new PointF((this.Width - drawW) / 2, (this.Height - drawH) / 2);

            this.Invalidate();
            TriggerStatusChange();
        }

        protected override void OnMouseDown(MouseEventArgs e)
        {
            base.OnMouseDown(e);
            if (e.Button == MouseButtons.Left)
            {
                _isDragging = true;
                _lastMousePos = e.Location;
            }
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            base.OnMouseUp(e);
            _isDragging = false;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            base.OnMouseMove(e);

            if (_isDragging)
            {
                _panOffset.X += e.X - _lastMousePos.X;
                _panOffset.Y += e.Y - _lastMousePos.Y;
                _lastMousePos = e.Location;
                this.Invalidate();
            }

            if (this.Image != null && this.Image is Bitmap bmp)
            {
                float imgXf = (e.X - _panOffset.X) / _zoom;
                float imgYf = (e.Y - _panOffset.Y) / _zoom;
                int imgX = (int)imgXf;
                int imgY = (int)imgYf;

                if (imgX >= 0 && imgX < bmp.Width && imgY >= 0 && imgY < bmp.Height)
                {
                    _lastImgX = imgX;
                    _lastImgY = imgY;
                    _lastColor = bmp.GetPixel(imgX, imgY);
                }

                TriggerStatusChange();
            }
        }

        protected override void OnMouseWheel(MouseEventArgs e)
        {
            float oldZoom = _zoom;
            float factor = 1.1f;

            if (e.Delta > 0) _zoom *= factor;
            else _zoom /= factor;

            if (_zoom < 0.01f) _zoom = 0.01f;
            if (_zoom > 100.0f) _zoom = 100.0f;

            float scaleChange = _zoom / oldZoom;

            _panOffset.X = e.X - (e.X - _panOffset.X) * scaleChange;
            _panOffset.Y = e.Y - (e.Y - _panOffset.Y) * scaleChange;

            this.Invalidate();
            TriggerStatusChange();
        }

        protected override void OnPaint(PaintEventArgs pe)
        {
            if (this.Image == null) { base.OnPaint(pe); return; }

            pe.Graphics.InterpolationMode = InterpolationMode.NearestNeighbor;
            pe.Graphics.PixelOffsetMode = PixelOffsetMode.Half;

            float drawW = this.Image.Width * _zoom;
            float drawH = this.Image.Height * _zoom;

            pe.Graphics.DrawImage(this.Image, _panOffset.X, _panOffset.Y, drawW, drawH);
        }
    }
}
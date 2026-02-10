using System;
using System.Collections.Generic;
using System.Drawing;
using System.Threading.Tasks;
using System.Windows.Forms;
using Matrox.MatroxImagingLibrary;

namespace Envision_MdigGrab
{
    public partial class Form1 : Form
    {
        // 定義相機設定結構 (方便未來擴充)
        private class CameraConfig
        {
            public int Id { get; set; }
            public MIL_INT DevNum { get; set; }
            public string DcfPath { get; set; }
            public Panel DisplayPanel { get; set; }
            public Label StatusLabel { get; set; } // 每支相機的狀態燈 (Online/Offline)
        }

        // 相機物件列表
        private List<MilCameraUnit> _cameras = new List<MilCameraUnit>();
        private List<CameraConfig> _configs;

        // 全域控制變數
        private System.Windows.Forms.Timer statusTimer;
        private bool _userWantsGrab = false;
        private volatile bool _isReleasing = false;

        // 共用的座標顯示 Label (假設你在 Form 上拉了一個叫 labelGlobalCoord 的 Label)
        // 若你的 label 名稱不同，請在此修改或在 InitializeComponent 後指派
        private Label _sharedCoordLabel;

        public Form1()
        {
            InitializeComponent();

            // 設定共用的 Label (請確認你的 Form 上有這個 Label，或者把這裡改成你現有的 Label)
            _sharedCoordLabel = labelCoord1; // 假設你用 labelCoord1 當作顯示用的 Label

            // 初始化設定清單 (要加第3支相機就在這加)
            _configs = new List<CameraConfig>
            {
                new CameraConfig { Id = 1, DevNum = MIL.M_DEV0, DcfPath = @"C:\Users\User\Downloads\dcf\Radient eV-CL Dual-Base-Digitizer0_FreeRun.dcf", DisplayPanel = panel1, StatusLabel = label1 },
                new CameraConfig { Id = 2, DevNum = MIL.M_DEV1, DcfPath = @"C:\Users\User\Downloads\dcf\Radient eV-CL Dual-Base-Digitizer1_FreeRun.dcf", DisplayPanel = panel2, StatusLabel = label2 }
                // new CameraConfig { Id = 3, DevNum = MIL.M_DEV2, ... } 
            };

            statusTimer = new System.Windows.Forms.Timer();
            statusTimer.Interval = 500;
            statusTimer.Tick += StatusTimer_Tick;

            // 初始 UI 狀態
            foreach (var cfg in _configs) UpdateStatusUI(cfg.Id, false);
            UpdateGlobalCoordLabel("Ready");
        }

        // ================= Button Events =================

        private void button1_Click(object sender, EventArgs e)
        {
            if (_cameras.Count > 0) return; // 避免重複初始化

            _isReleasing = false;
            _userWantsGrab = false;

            // 1. 初始化 System
            MilSystemManager.Initialize();

            // 2. 根據設定檔迴圈建立相機
            foreach (var cfg in _configs)
            {
                var cam = new MilCameraUnit(cfg.Id, cfg.DevNum, cfg.DcfPath, cfg.DisplayPanel.Handle);

                // 訂閱事件：所有相機都呼叫同一個 UpdateGlobalCoordLabel
                cam.OnMouseDataChanged += UpdateGlobalCoordLabel_FromCamera;

                cam.Initialize();
                _cameras.Add(cam);
            }

            statusTimer.Start();
        }

        private void button2_Click(object sender, EventArgs e)
        {
            _userWantsGrab = !_userWantsGrab;
            foreach (var cam in _cameras)
            {
                cam.SetUserGrabIntent(_userWantsGrab);
            }
        }

        private async void button3_Click(object sender, EventArgs e)
        {
            _isReleasing = true;
            statusTimer.Stop();

            SetButtonsEnabled(false);

            await Task.Run(() =>
            {
                foreach (var cam in _cameras)
                {
                    cam.Free();
                }
                _cameras.Clear(); // 清空列表
                MilSystemManager.Free();
            });

            ResetUI();
            SetButtonsEnabled(true);
        }

        // ================= UI Update Logic =================

        // 這是所有相機共用的滑鼠事件處理器
        private void UpdateGlobalCoordLabel_FromCamera(int camId, int x, int y, int val)
        {
            // 這裡可以加上 "CAM 1: " 讓使用者知道現在滑鼠在哪個視窗
            string text = (val != -1)
                ? $"[CAM {camId}] X: {x}, Y: {y} | Val: {val}"
                : $"[CAM {camId}] Out of Range";

            UpdateGlobalCoordLabel(text);
        }

        private void UpdateGlobalCoordLabel(string text)
        {
            if (_sharedCoordLabel == null) return;

            if (_sharedCoordLabel.InvokeRequired)
            {
                _sharedCoordLabel.BeginInvoke(new Action(() => UpdateGlobalCoordLabel(text)));
            }
            else
            {
                _sharedCoordLabel.Text = text;
            }
        }

        private void StatusTimer_Tick(object sender, EventArgs e)
        {
            if (_isReleasing) return;
            foreach (var cam in _cameras)
            {
                UpdateStatusUI(cam.CameraId, cam.CheckPresence());
            }
        }

        private void UpdateStatusUI(int id, bool isConnected)
        {
            // 找到對應的設定檔來更新 Label
            var cfg = _configs.Find(c => c.Id == id);
            if (cfg == null || cfg.StatusLabel == null) return;

            if (this.InvokeRequired)
            {
                this.BeginInvoke(new Action(() => UpdateStatusUI(id, isConnected)));
                return;
            }

            string statusText = isConnected ? $"Camera {id}: Online" : $"Camera {id}: Offline";
            Color backColor = isConnected ? Color.LightGreen : Color.Red;

            if (cfg.StatusLabel.Text != statusText)
            {
                cfg.StatusLabel.Text = statusText;
                cfg.StatusLabel.BackColor = backColor;
                cfg.StatusLabel.ForeColor = isConnected ? Color.Black : Color.White;
            }
        }

        private void ResetUI()
        {
            foreach (var cfg in _configs) UpdateStatusUI(cfg.Id, false);
            _userWantsGrab = false;
            UpdateGlobalCoordLabel("System Released");
        }

        private void SetButtonsEnabled(bool enabled)
        {
            button1.Enabled = enabled;
            button2.Enabled = enabled;
            button3.Enabled = enabled;
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            _isReleasing = true;
            statusTimer.Stop();
            foreach (var cam in _cameras) cam.Free();
            MilSystemManager.Free();
            base.OnFormClosing(e);
        }
    }
}
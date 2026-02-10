using System;
using System.Threading;
using Matrox.MatroxImagingLibrary;

namespace Envision_MdigGrab
{
    public class MilCameraUnit
    {
        public MIL_ID MilDigitizer = MIL.M_NULL;
        public MIL_ID MilDisplay = MIL.M_NULL;
        public MIL_ID MilImage = MIL.M_NULL;

        public bool IsLive { get; private set; } = false;
        public int CameraId { get; private set; }
        public bool IsConnected { get; private set; } = false; // 新增狀態快取

        private bool _userWantsGrab = false;
        private bool _isReleased = false;

        private MIL_INT _devNum;
        private string _dcfPath;
        private IntPtr _panelHandle;

        // 避免 GC 回收的委派
        private MIL_DIG_HOOK_FUNCTION_PTR _cameraStatusDelegate;
        private MIL_DISP_HOOK_FUNCTION_PTR _mouseStatusDelegate;

        // 事件：回傳 (CameraID, X, Y, PixelValue)
        public event Action<int, int, int, int> OnMouseDataChanged;

        public MilCameraUnit(int id, MIL_INT devNum, string dcfPath, IntPtr panelHandle)
        {
            CameraId = id;
            _devNum = devNum;
            _dcfPath = dcfPath;
            _panelHandle = panelHandle;

            _cameraStatusDelegate = new MIL_DIG_HOOK_FUNCTION_PTR(CameraStatusHandler);
            _mouseStatusDelegate = new MIL_DISP_HOOK_FUNCTION_PTR(MouseStatusHandler);
        }

        public void Initialize()
        {
            if (MilSystemManager.MilSystem == MIL.M_NULL) return;

            MIL.MdigAlloc(MilSystemManager.MilSystem, _devNum, _dcfPath, MIL.M_DEFAULT, ref MilDigitizer);

            if (MilDigitizer != MIL.M_NULL)
            {
                MIL.MdigControl(MilDigitizer, MIL.M_GRAB_TIMEOUT, 1000);

                MIL.MdispAlloc(MilSystemManager.MilSystem, MIL.M_DEFAULT, "M_DEFAULT", MIL.M_DEFAULT, ref MilDisplay);

                MIL_INT sizeX = MIL.MdigInquire(MilDigitizer, MIL.M_SIZE_X, MIL.M_NULL);
                MIL_INT sizeY = MIL.MdigInquire(MilDigitizer, MIL.M_SIZE_Y, MIL.M_NULL);
                MIL.MbufAlloc2d(MilSystemManager.MilSystem, sizeX, sizeY, 8 + MIL.M_UNSIGNED, MIL.M_IMAGE + MIL.M_GRAB + MIL.M_DISP, ref MilImage);
                MIL.MbufClear(MilImage, 0);

                MIL.MdispSelectWindow(MilDisplay, MilImage, _panelHandle);

                // 顯示設定
                MIL.MdispControl(MilDisplay, MIL.M_SCALE_DISPLAY, MIL.M_ONCE);   // 自動適配一次
                MIL.MdispControl(MilDisplay, MIL.M_CENTER_DISPLAY, MIL.M_ENABLE); // 保持置中
                MIL.MdispControl(MilDisplay, MIL.M_MOUSE_USE, MIL.M_ENABLE);      // 啟用滑鼠互動
                MIL.MdispControl(MilDisplay, MIL.M_INTERPOLATION_MODE, MIL.M_NEAREST_NEIGHBOR);

                // 註冊 Hooks
                MIL.MdispHookFunction(MilDisplay, MIL.M_MOUSE_MOVE, _mouseStatusDelegate, (IntPtr)CameraId);
                MIL.MdigHookFunction(MilDigitizer, MIL.M_CAMERA_PRESENT, _cameraStatusDelegate, (IntPtr)CameraId);
            }
        }

        public void SetUserGrabIntent(bool enable)
        {
            _userWantsGrab = enable;
            ApplyGrabState();
        }

        private void ApplyGrabState()
        {
            if (MilDigitizer == MIL.M_NULL) return;
            try
            {
                if (_userWantsGrab)
                {
                    if (!IsLive && CheckPresence())
                    {
                        MIL.MdigHalt(MilDigitizer);
                        MIL.MdigGrabContinuous(MilDigitizer, MilImage);
                        IsLive = true;
                    }
                }
                else
                {
                    if (IsLive)
                    {
                        MIL.MdigHalt(MilDigitizer);
                        IsLive = false;
                    }
                }
            }
            catch { }
        }

        public bool CheckPresence()
        {
            if (MilDigitizer == MIL.M_NULL) { IsConnected = false; return false; }
            try
            {
                MIL_INT presence = 0;
                MIL.MdigInquire(MilDigitizer, MIL.M_CAMERA_PRESENT, ref presence);
                IsConnected = (presence == MIL.M_YES || presence == MIL.M_SUPPORTED);
                return IsConnected;
            }
            catch { IsConnected = false; return false; }
        }

        public void Free()
        {
            _isReleased = true;
            if (MilDigitizer != MIL.M_NULL)
            {
                MIL.MdigHookFunction(MilDigitizer, MIL.M_CAMERA_PRESENT + MIL.M_UNHOOK, _cameraStatusDelegate, IntPtr.Zero);
                if (MilDisplay != MIL.M_NULL)
                    MIL.MdispHookFunction(MilDisplay, MIL.M_MOUSE_MOVE + MIL.M_UNHOOK, _mouseStatusDelegate, IntPtr.Zero);

                MIL.MdigHalt(MilDigitizer);
                if (MilImage != MIL.M_NULL) MIL.MbufFree(MilImage);
                if (MilDisplay != MIL.M_NULL) MIL.MdispFree(MilDisplay);
                MIL.MdigFree(MilDigitizer);

                MilDigitizer = MIL.M_NULL;
            }
        }

        // ================= Hook Handlers =================

        private MIL_INT MouseStatusHandler(MIL_INT HookType, MIL_ID EventId, IntPtr UserPtr)
        {
            if (_isReleased || MilImage == MIL.M_NULL) return MIL.M_NULL;

            double posX = 0, posY = 0;
            MIL.MdispGetHookInfo(EventId, MIL.M_MOUSE_POSITION_BUFFER_X, ref posX);
            MIL.MdispGetHookInfo(EventId, MIL.M_MOUSE_POSITION_BUFFER_Y, ref posY);

            int x = (int)posX;
            int y = (int)posY;
            int pixelValue = -1;

            MIL_INT sizeX = MIL.MbufInquire(MilImage, MIL.M_SIZE_X, MIL.M_NULL);
            MIL_INT sizeY = MIL.MbufInquire(MilImage, MIL.M_SIZE_Y, MIL.M_NULL);

            if (x >= 0 && x < sizeX && y >= 0 && y < sizeY)
            {
                byte[] data = new byte[1];
                MIL.MbufGet2d(MilImage, x, y, 1, 1, data);
                pixelValue = data[0];
            }

            // 這裡將 CameraId 一併傳出去，讓 Form 知道是哪支相機
            OnMouseDataChanged?.Invoke(CameraId, x, y, pixelValue);
            return MIL.M_NULL;
        }

        private MIL_INT CameraStatusHandler(MIL_INT HookType, MIL_ID EventId, IntPtr UserPtr)
        {
            if (_isReleased) return MIL.M_NULL;

            if (CheckPresence())
            {
                MIL.MdigHalt(MilDigitizer);
                Thread.Sleep(1500);
                if (_userWantsGrab)
                {
                    MIL.MdigGrabContinuous(MilDigitizer, MilImage);
                    IsLive = true;
                }
            }
            else
            {
                MIL.MdigHalt(MilDigitizer);
                IsLive = false;
            }
            return MIL.M_NULL;
        }
    }
}
using System;
using System.Runtime.InteropServices;
using System.Threading;
using Matrox.MatroxImagingLibrary;

namespace Envision_MdigGrab
{
    public class MilCameraUnit
    {
        public MIL_ID MilDigitizer = MIL.M_NULL;
        public MIL_ID MilDisplay = MIL.M_NULL;

        // 用於 MdigProcess 的雙緩衝區 (接收相機資料)
        private MIL_ID[] _milGrabBuffers = new MIL_ID[2];
        private MIL_INT _milGrabBufferListSize = 2;

        // [新增] 用於顯示的專用緩衝區 (解決滑鼠互動問題)
        private MIL_ID _milDisplayBuffer = MIL.M_NULL;

        public bool IsLive { get; private set; } = false;
        public int CameraId { get; private set; }
        public bool IsConnected { get; private set; } = false;

        // 公開屬性讓 Form 判斷是否需要重啟
        public bool UserWantsGrab => _userWantsGrab;

        private bool _userWantsGrab = false;
        private bool _isReleased = false;
        private MIL_INT _devNum;
        private string _dcfPath;
        private IntPtr _panelHandle;

        private MIL_DIG_HOOK_FUNCTION_PTR _cameraStatusDelegate;
        private MIL_DISP_HOOK_FUNCTION_PTR _mouseStatusDelegate;
        private MIL_DIG_HOOK_FUNCTION_PTR _processingDelegate;
        private GCHandle _hUserData;

        public event Action<int, int, int, int> OnMouseDataChanged;

        public MilCameraUnit(int id, MIL_INT devNum, string dcfPath, IntPtr panelHandle)
        {
            CameraId = id;
            _devNum = devNum;
            _dcfPath = dcfPath;
            _panelHandle = panelHandle;

            _cameraStatusDelegate = new MIL_DIG_HOOK_FUNCTION_PTR(CameraStatusHandler);
            _mouseStatusDelegate = new MIL_DISP_HOOK_FUNCTION_PTR(MouseStatusHandler);
            _processingDelegate = new MIL_DIG_HOOK_FUNCTION_PTR(ProcessingFunction);
            _hUserData = GCHandle.Alloc(this);
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

                // 1. 分配 MdigProcess 用的雙緩衝
                for (int i = 0; i < _milGrabBufferListSize; i++)
                {
                    MIL.MbufAlloc2d(MilSystemManager.MilSystem, sizeX, sizeY, 8 + MIL.M_UNSIGNED,
                        MIL.M_IMAGE + MIL.M_GRAB + MIL.M_PROC, ref _milGrabBuffers[i]);
                    MIL.MbufClear(_milGrabBuffers[i], 0);
                }

                // 2. [關鍵修正] 分配獨立的顯示緩衝區 (Display Buffer)
                // 加上 MIL.M_DISP 屬性
                MIL.MbufAlloc2d(MilSystemManager.MilSystem, sizeX, sizeY, 8 + MIL.M_UNSIGNED,
                    MIL.M_IMAGE + MIL.M_DISP + MIL.M_PROC, ref _milDisplayBuffer);
                MIL.MbufClear(_milDisplayBuffer, 0);

                // 3. 將 Display 固定綁定在這個 Buffer 上，永遠不切換
                MIL.MdispSelectWindow(MilDisplay, _milDisplayBuffer, _panelHandle);

                MIL.MdispControl(MilDisplay, MIL.M_SCALE_DISPLAY, MIL.M_ONCE);
                MIL.MdispControl(MilDisplay, MIL.M_CENTER_DISPLAY, MIL.M_ENABLE);
                MIL.MdispControl(MilDisplay, MIL.M_MOUSE_USE, MIL.M_ENABLE); // 啟用滑鼠互動

                // Hooks
                MIL.MdispHookFunction(MilDisplay, MIL.M_MOUSE_MOVE, _mouseStatusDelegate, (IntPtr)CameraId);
                MIL.MdigHookFunction(MilDigitizer, MIL.M_CAMERA_PRESENT, _cameraStatusDelegate, (IntPtr)CameraId);
            }
        }

        // MdigProcess 的 Callback
        private static MIL_INT ProcessingFunction(MIL_INT HookType, MIL_ID EventId, IntPtr UserPtr)
        {
            if (UserPtr == IntPtr.Zero) return MIL.M_NULL;

            GCHandle hObj = GCHandle.FromIntPtr(UserPtr);
            var cam = hObj.Target as MilCameraUnit;
            if (cam == null || cam._isReleased) return MIL.M_NULL;

            MIL_ID modifiedBuffer = MIL.M_NULL;

            // 取得當前寫入完成的 Buffer ID
            MIL.MdigGetHookInfo(EventId, MIL.M_MODIFIED_BUFFER + MIL.M_BUFFER_ID, ref modifiedBuffer);

            // [關鍵修正] 使用 Copy 取代 SelectWindow
            // 將影像資料複製到顯示專用的 Buffer，這樣 Display 的 Handle 就不會變動，滑鼠拖曳就不會斷
            if (modifiedBuffer != MIL.M_NULL && cam._milDisplayBuffer != MIL.M_NULL)
            {
                MIL.MbufCopy(modifiedBuffer, cam._milDisplayBuffer);
            }

            return MIL.M_NULL;
        }

        public void SetUserGrabIntent(bool enable)
        {
            _userWantsGrab = enable;
            ApplyGrabState();
        }

        // 這個方法現在可以被外部 (如 Timer) 重複呼叫來嘗試啟動
        public void ApplyGrabState()
        {
            if (MilDigitizer == MIL.M_NULL) return;

            // 如果使用者想取像 + 目前沒在跑 + 相機在線 -> 啟動
            if (_userWantsGrab && !IsLive && CheckPresence())
            {
                MIL.MdigProcess(MilDigitizer, _milGrabBuffers, _milGrabBufferListSize, MIL.M_START, MIL.M_DEFAULT, _processingDelegate, GCHandle.ToIntPtr(_hUserData));
                IsLive = true;
            }
            // 如果使用者不想取像 + 目前正在跑 -> 停止
            else if (!_userWantsGrab && IsLive)
            {
                MIL.MdigProcess(MilDigitizer, _milGrabBuffers, _milGrabBufferListSize, MIL.M_STOP, MIL.M_DEFAULT, _processingDelegate, GCHandle.ToIntPtr(_hUserData));
                IsLive = false;
            }
        }

        public bool CheckPresence()
        {
            if (MilDigitizer == MIL.M_NULL) { IsConnected = false; return false; }
            MIL_INT presence = 0;
            MIL.MdigInquire(MilDigitizer, MIL.M_CAMERA_PRESENT, ref presence);
            IsConnected = (presence == MIL.M_YES);
            return IsConnected;
        }

        public void Free()
        {
            _isReleased = true;

            if (MilDigitizer != MIL.M_NULL)
            {
                MIL.MdigProcess(MilDigitizer, _milGrabBuffers, _milGrabBufferListSize, MIL.M_STOP, MIL.M_DEFAULT, _processingDelegate, GCHandle.ToIntPtr(_hUserData));
                IsLive = false;

                MIL.MdigHookFunction(MilDigitizer, MIL.M_CAMERA_PRESENT + MIL.M_UNHOOK, _cameraStatusDelegate, IntPtr.Zero);
                if (MilDisplay != MIL.M_NULL)
                    MIL.MdispHookFunction(MilDisplay, MIL.M_MOUSE_MOVE + MIL.M_UNHOOK, _mouseStatusDelegate, IntPtr.Zero);

                if (MilDisplay != MIL.M_NULL)
                    MIL.MdispSelectWindow(MilDisplay, MIL.M_NULL, IntPtr.Zero);

                // 釋放 Grab Buffers
                for (int i = 0; i < _milGrabBufferListSize; i++)
                {
                    if (_milGrabBuffers[i] != MIL.M_NULL)
                    {
                        MIL.MbufFree(_milGrabBuffers[i]);
                        _milGrabBuffers[i] = MIL.M_NULL;
                    }
                }

                // [新增] 釋放 Display Buffer
                if (_milDisplayBuffer != MIL.M_NULL)
                {
                    MIL.MbufFree(_milDisplayBuffer);
                    _milDisplayBuffer = MIL.M_NULL;
                }

                if (MilDisplay != MIL.M_NULL) { MIL.MdispFree(MilDisplay); MilDisplay = MIL.M_NULL; }
                MIL.MdigFree(MilDigitizer);
                MilDigitizer = MIL.M_NULL;
            }

            if (_hUserData.IsAllocated) _hUserData.Free();
        }

        private MIL_INT MouseStatusHandler(MIL_INT HookType, MIL_ID EventId, IntPtr UserPtr)
        {
            // 改為讀取 Display Buffer 的數值
            if (_isReleased || _milDisplayBuffer == MIL.M_NULL) return MIL.M_NULL;

            double posX = 0, posY = 0;
            MIL.MdispGetHookInfo(EventId, MIL.M_MOUSE_POSITION_BUFFER_X, ref posX);
            MIL.MdispGetHookInfo(EventId, MIL.M_MOUSE_POSITION_BUFFER_Y, ref posY);

            int x = (int)posX;
            int y = (int)posY;
            int pixelValue = -1;

            MIL_INT sizeX = MIL.MbufInquire(_milDisplayBuffer, MIL.M_SIZE_X, MIL.M_NULL);
            MIL_INT sizeY = MIL.MbufInquire(_milDisplayBuffer, MIL.M_SIZE_Y, MIL.M_NULL);

            if (x >= 0 && x < sizeX && y >= 0 && y < sizeY)
            {
                byte[] data = new byte[1];
                MIL.MbufGet2d(_milDisplayBuffer, x, y, 1, 1, data);
                pixelValue = data[0];
            }

            OnMouseDataChanged?.Invoke(CameraId, x, y, pixelValue);
            return MIL.M_NULL;
        }

        private MIL_INT CameraStatusHandler(MIL_INT HookType, MIL_ID EventId, IntPtr UserPtr)
        {
            if (_isReleased) return MIL.M_NULL;

            bool present = CheckPresence();

            // 只有當「斷線」且「正在跑」的時候，才需要強制停止
            // 重新連線的啟動工作交給 Form1 的 Timer 來做，避免執行緒問題
            if (!present && IsLive)
            {
                MIL.MdigProcess(MilDigitizer, _milGrabBuffers, _milGrabBufferListSize, MIL.M_STOP, MIL.M_DEFAULT, _processingDelegate, GCHandle.ToIntPtr(_hUserData));
                IsLive = false;
            }
            return MIL.M_NULL;
        }
    }
}
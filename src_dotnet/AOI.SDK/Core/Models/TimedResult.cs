using System;

namespace AOI.SDK.Core.Models
{
    /// <summary>
    /// 通用的計時結果容器，用於封裝資料與 IO/運算耗時。
    /// </summary>
    /// <typeparam name="T">資料型別 (如 Bitmap)</typeparam>
    public class TimedResult<T> : IDisposable
    {
        public T Data { get; set; }
        public long IoDurationMs { get; set; }      // IO 耗時 (讀檔/傳輸)
        public long ComputeDurationMs { get; set; } // 運算耗時 (GPU/CPU)

        public TimedResult() { }

        public TimedResult(T data, long ioMs, long computeMs)
        {
            Data = data;
            IoDurationMs = ioMs;
            ComputeDurationMs = computeMs;
        }

        public void Dispose()
        {
            if (Data is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }
}
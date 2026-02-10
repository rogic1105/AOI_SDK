using Matrox.MatroxImagingLibrary;

namespace Envision_MdigGrab
{
    public static class MilSystemManager
    {
        public static MIL_ID MilApplication = MIL.M_NULL;
        public static MIL_ID MilSystem = MIL.M_NULL;
        private static bool _isInitialized = false;

        public static void Initialize()
        {
            if (_isInitialized) return;
            MIL.MappAllocDefault(MIL.M_DEFAULT, ref MilApplication, ref MilSystem, MIL.M_NULL, MIL.M_NULL, MIL.M_NULL);
            MIL.MappControl(MIL.M_DEFAULT, MIL.M_ERROR, MIL.M_PRINT_DISABLE);
            _isInitialized = true;
        }

        public static void Free()
        {
            if (MilApplication != MIL.M_NULL)
            {
                MIL.MappFreeDefault(MilApplication, MilSystem, MIL.M_NULL, MIL.M_NULL, MIL.M_NULL);
                MilSystem = MIL.M_NULL;
                MilApplication = MIL.M_NULL;
                _isInitialized = false;
            }
        }
    }
}
// 這裡專門負責編譯 STB 實作，其他地方只要 include .h 檔就好
#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_WRITE_IMPLEMENTATION
#define _CRT_SECURE_NO_WARNINGS 

#include "stb/stb_image.h"
#include "stb/stb_image_write.h"
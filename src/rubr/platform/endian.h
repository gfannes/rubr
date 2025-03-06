#ifndef HEADER_rubr_platform_endian_h_ALREADY_INCLUDED
#define HEADER_rubr_platform_endian_h_ALREADY_INCLUDED

#include <rubr/platform/os.h>

#if defined(__GNUC__)

    #if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
        #define RUBR_PLATFORM_ENDIAN "little"
        #define RUBR_PLATFORM_ENDIAN_LITTLE 1
    #endif
    #if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
        #define RUBR_PLATFORM_ENDIAN "big"
        #define RUBR_PLATFORM_ENDIAN_BIG 1
    #endif

#else

    #if RUBR_PLATFORM_OS_WINDOWS
        #define RUBR_PLATFORM_ENDIAN "little"
        #define RUBR_PLATFORM_ENDIAN_LITTLE 1
    #endif

#endif

#endif

#ifndef HEADER_rubr_platform_h_ALREADY_INCLUDED
#define HEADER_rubr_platform_h_ALREADY_INCLUDED

#include <rubr/platform/compiler.h>
#if !defined(RUBR_PLATFORM_COMPILER)
    #error RUBR_PLATFORM_COMPILER define not set
#endif
#if !defined(RUBR_PLATFORM_COMPILER_VERSION)
    #error RUBR_PLATFORM_COMPILER_VERSION define not set
#endif
#if !defined(RUBR_PLATFORM_DEBUG)
    #error RUBR_PLATFORM_DEBUG define not set
#endif
#if !RUBR_PLATFORM_COMPILER_GCC && !RUBR_PLATFORM_COMPILER_MSVC
    #error Unknown compiler brand
#endif

#include <rubr/platform/os.h>
#if !defined(RUBR_PLATFORM_OS)
    #error RUBR_PLATFORM_OS define not set
#endif

#include <rubr/platform/endian.h>
#if !defined(RUBR_PLATFORM_ENDIAN) || (!RUBR_PLATFORM_ENDIAN_LITTLE && !RUBR_PLATFORM_ENDIAN_BIG)
    #error Not all endian defines are set
#endif

#if 0
    #if !defined(RUBR_PLATFORM_BITS)
        #error RUBR_PLATFORM_BITS is not available
    #endif
    #if !defined(RUBR_PLATFORM_ARCH)
        #error RUBR_PLATFORM_ARCH is not available
    #endif
#endif

#endif

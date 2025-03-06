#ifndef HEADER_rubr_platform_compiler_h_ALREADY_INCLUDED
#define HEADER_rubr_platform_compiler_h_ALREADY_INCLUDED

#if defined(__GNUC__)
    #define RUBR_PLATFORM_COMPILER "gcc"
    #define RUBR_PLATFORM_COMPILER_GCC 1
    #define RUBR_PLATFORM_COMPILER_VERSION (__GNUC__ * 10000 + __GNUC_MINOR__ * 100 + __GNUC_PATCHLEVEL__)
#endif

#if defined(_MSC_VER)
    #define RUBR_PLATFORM_COMPILER "msvc"
    #define RUBR_PLATFORM_COMPILER_MSVC 1
    #define RUBR_PLATFORM_COMPILER_VERSION (_MSC_FULL_VER / 1000)
#endif

#if defined(NDEBUG)
    #define RUBR_PLATFORM_DEBUG 0
#else
    #define RUBR_PLATFORM_DEBUG 1
#endif

#endif

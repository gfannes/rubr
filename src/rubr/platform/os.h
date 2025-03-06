#ifndef HEADER_rubr_platform_os_h_ALREADY_INCLUDED
#define HEADER_rubr_platform_os_h_ALREADY_INCLUDED

#if defined(linux) || defined(__linux)
    #define RUBR_PLATFORM_OS "linux"
    #define RUBR_PLATFORM_OS_LINUX 1
    #define RUBR_PLATFORM_API_POSIX 1
#endif

#if defined(macintosh) || defined(Macintosh) || defined(__APPLE__) || defined(__MACH__)
    #define RUBR_PLATFORM_OS "osx"
    #define RUBR_PLATFORM_OS_OSX 1
    #define RUBR_PLATFORM_API_POSIX 1
    #include <AvailabilityMacros.h>
    #define RUBR_PLATFORM_OS_OSX_VERSION MAC_OS_X_VERSION_MAX_ALLOWED
#endif

#if defined(_WIN32) || defined(_WIN64) || defined(__WIN32__) || defined(__WINDOWS__)
    #define RUBR_PLATFORM_OS "windows"
    #define RUBR_PLATFORM_OS_WINDOWS 1
    #define RUBR_PLATFORM_API_WIN32 1
    #if defined(__MINGW32__)
        #define RUBR_PLATFORM_API_MINGW 1
        #define RUBR_PLATFORM_API_POSIX 1
    #endif
#endif

#if defined(ARDUINO)
    #define RUBR_PLATFORM_OS "arduino"
    #define RUBR_PLATFORM_OS_ARDUINO 1
    #if defined(ARDUINO_AVR_MEGA2560)
        #define RUBR_PLATFORM_ARDUINO_MEGA 1
    #endif
    #if defined(ARDUINO_AVR_UNO)
        #define RUBR_PLATFORM_ARDUINO_UNO 1
    #endif
#endif

#endif

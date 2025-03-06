#ifndef HEADER_rubr_debug_log_hpp_ALREAD_INCLUDED
#define HEADER_rubr_debug_log_hpp_ALREAD_INCLUDED

#ifndef RUBR_DEBUG_LOG_ACTIVE
    #include <rubr/platform.h>
    #if RUBR_PLATFORM_DEBUG
        #define RUBR_DEBUG_LOG_ACTIVE 1
    #else
        #define RUBR_DEBUG_LOG_ACTIVE 0
    #endif
#endif

#if RUBR_DEBUG_LOG_ACTIVE
    #include <rubr/debug/log/cout.hpp>
#else
    #include <rubr/debug/log/noop.hpp>
#endif

#endif

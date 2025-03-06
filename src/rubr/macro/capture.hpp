#ifndef HEADER_rubr_macro_capture_hpp_ALREADY_INCLUDED
#define HEADER_rubr_macro_capture_hpp_ALREADY_INCLUDED

#include <rubr/macro/variadic.h>

#ifdef C
    #error C already defined
#endif

#define C_1(var) "(" #var ":" << var << ")"
#define C_2(var, type) "(" #var ":" << type(var) << ")"
#define C(...) RUBR_GET_ARG_3((__VA_ARGS__, C_2, C_1))(__VA_ARGS__)

#endif

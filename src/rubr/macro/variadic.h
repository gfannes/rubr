#ifndef HEADER_rubr_macro_variadic_h_ALREADY_INCLUDED
#define HEADER_rubr_macro_variadic_h_ALREADY_INCLUDED

// Macro dispatching
// #define <MACRO_NAME>_1(_1) bla(_1)
// #define <MACRO_NAME>_2(_1, _2) bli(_1, _2)
// #define <MACRO_NAME>(...) RUBR_GET_ARG_3((__VA_ARGS__, <MACRO_NAME>_2,<MACRO_NAME>_1))(__VA_ARGS__)
#define RUBR_GET_ARG_1_(N, ...) N
#define RUBR_GET_ARG_1(tuple) RUBR_GET_ARG_1_ tuple
#define RUBR_GET_ARG_2_(_1, N, ...) N
#define RUBR_GET_ARG_2(tuple) RUBR_GET_ARG_2_ tuple
#define RUBR_GET_ARG_3_(_1, _2, N, ...) N
#define RUBR_GET_ARG_3(tuple) RUBR_GET_ARG_3_ tuple
#define RUBR_GET_ARG_4_(_1, _2, _3, N, ...) N
#define RUBR_GET_ARG_4(tuple) RUBR_GET_ARG_4_ tuple
#define RUBR_GET_ARG_5_(_1, _2, _3, _4, N, ...) N
#define RUBR_GET_ARG_5(tuple) RUBR_GET_ARG_5_ tuple
#define RUBR_GET_ARG_6_(_1, _2, _3, _4, _5, N, ...) N
#define RUBR_GET_ARG_6(tuple) RUBR_GET_ARG_6_ tuple
#define RUBR_GET_ARG_7_(_1, _2, _3, _4, _5, _6, N, ...) N
#define RUBR_GET_ARG_7(tuple) RUBR_GET_ARG_7_ tuple
#define RUBR_GET_ARG_8_(_1, _2, _3, _4, _5, _6, _7, N, ...) N
#define RUBR_GET_ARG_8(tuple) RUBR_GET_ARG_8_ tuple
#define RUBR_GET_ARG_9_(_1, _2, _3, _4, _5, _6, _7, _8, N, ...) N
#define RUBR_GET_ARG_9(tuple) RUBR_GET_ARG_9_ tuple
#define RUBR_GET_ARG_10_(_1, _2, _3, _4, _5, _6, _7, _8, _9, N, ...) N
#define RUBR_GET_ARG_10(tuple) RUBR_GET_ARG_10_ tuple
#define RUBR_GET_ARG_11_(_1, _2, _3, _4, _5, _6, _7, _8, _9, _10, N, ...) N
#define RUBR_GET_ARG_11(tuple) RUBR_GET_ARG_11_ tuple

#endif

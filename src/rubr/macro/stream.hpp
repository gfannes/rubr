#ifndef HEADER_rubr_macro_stream_hpp_ALREADY_INCLUDED
#define HEADER_rubr_macro_stream_hpp_ALREADY_INCLUDED

#include <rubr/macro/variadic.h>

// Streaming of variables
#define STREAM_FORMAT_A(var) "{" #var ": " << var <<
#define STREAM_FORMAT_B(var) ", " #var ": " << var <<
#define STREAM_1(_1) STREAM_FORMAT_A(_1)
#define STREAM_2(_1, _2) STREAM_1(_1) STREAM_FORMAT_B(_2)
#define STREAM_3(_1, _2, _3) STREAM_2(_1, _2) STREAM_FORMAT_B(_3)
#define STREAM_4(_1, _2, _3, _4) STREAM_3(_1, _2, _3) STREAM_FORMAT_B(_4)
#define STREAM_5(_1, _2, _3, _4, _5) STREAM_4(_1, _2, _3, _4) STREAM_FORMAT_B(_5)
#define STREAM_6(_1, _2, _3, _4, _5, _6) STREAM_5(_1, _2, _3, _4, _5) STREAM_FORMAT_B(_6)
#define STREAM_7(_1, _2, _3, _4, _5, _6, _7) STREAM_6(_1, _2, _3, _4, _5, _6) STREAM_FORMAT_B(_7)
#define STREAM_8(_1, _2, _3, _4, _5, _6, _7, _8) STREAM_7(_1, _2, _3, _4, _5, _6, _7) STREAM_FORMAT_B(_8)
#define STREAM_9(_1, _2, _3, _4, _5, _6, _7, _8, _9) STREAM_8(_1, _2, _3, _4, _5, _6, _7, _8) STREAM_FORMAT_B(_9)
#define STREAM_10(_1, _2, _3, _4, _5, _6, _7, _8, _9, _10) STREAM_9(_1, _2, _3, _4, _5, _6, _7, _8, _9) STREAM_FORMAT_B(_10)
#define STREAM(...) RUBR_GET_ARG_11((__VA_ARGS__, STREAM_10, STREAM_9, STREAM_8, STREAM_7, STREAM_6, STREAM_5, STREAM_4, STREAM_3, STREAM_2, STREAM_1))(__VA_ARGS__) "}"

#endif

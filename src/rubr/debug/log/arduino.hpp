#ifndef HEADER_rubr_debug_log_arduino_hpp_ALREADY_INCLUDED
#define HEADER_rubr_debug_log_arduino_hpp_ALREADY_INCLUDED

#define S(debug_ns) Serial.print(debug_ns)
#define L(msg)      Serial.print(#msg);Serial.println(msg)

#endif

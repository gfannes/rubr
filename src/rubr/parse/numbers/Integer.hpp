#ifndef HEADER_rubr_parse_numbers_Integer_hpp_ALREADY_INCLUDED
#define HEADER_rubr_parse_numbers_Integer_hpp_ALREADY_INCLUDED

#include <rubr/tmp/IntType.hpp>

#include <cstddef>

namespace rubr::parse::numbers {

    namespace priv {
        // 2**64: 18446744073709551616
        // 2**63: 9223372036854775808

        // No checks are performed on buf anymore, make sure it contains only digits
        inline bool read(long &l, const char *buf, size_t len, tmp::IntType<4>)
        {
            l = 0;
#define L_TABLE(n, m) const static unsigned long long lt_##n[] = {m * 0, m * 1, m * 2, m * 3, m * 4, m * 5, m * 6, m * 7, m * 8, m * 9};
            L_TABLE(1, 1ul);
            L_TABLE(2, 10ul);
            L_TABLE(3, 100ul);
            L_TABLE(4, 1000ul);
            L_TABLE(5, 10000ul);
            L_TABLE(6, 100000ul);
            L_TABLE(7, 1000000ul);
            L_TABLE(8, 10000000ul);
            L_TABLE(9, 100000000ul);
            L_TABLE(10, 1000000000ul);
#undef L_TABLE
            switch (len)
            {
                default:
                    // Number is too short or too long
                    return false;

#ifdef L_CASE
    #error L_CASE already defined
#endif
#define L_CASE(n) \
    case n: l += lt_##n[*buf++ - '0']
                    L_CASE(10);
                    L_CASE(9);
                    L_CASE(8);
                    L_CASE(7);
                    L_CASE(6);
                    L_CASE(5);
                    L_CASE(4);
                    L_CASE(3);
                    L_CASE(2);
                    L_CASE(1);
#undef L_CASE
            }
            return true;
        }

        inline bool read(long &l, const char *buf, size_t len, tmp::IntType<8>)
        {
            l = 0;
#define L_TABLE(n, m) const static unsigned long long lt_##n[] = {m * 0, m * 1, m * 2, m * 3, m * 4, m * 5, m * 6, m * 7, m * 8, m * 9};
            L_TABLE(1, 1ul);
            L_TABLE(2, 10ul);
            L_TABLE(3, 100ul);
            L_TABLE(4, 1000ul);
            L_TABLE(5, 10000ul);
            L_TABLE(6, 100000ul);
            L_TABLE(7, 1000000ul);
            L_TABLE(8, 10000000ul);
            L_TABLE(9, 100000000ul);
            L_TABLE(10, 1000000000ul);
            L_TABLE(11, 10000000000ul);
            L_TABLE(12, 100000000000ul);
            L_TABLE(13, 1000000000000ul);
            L_TABLE(14, 10000000000000ul);
            L_TABLE(15, 100000000000000ul);
            L_TABLE(16, 1000000000000000ul);
            L_TABLE(17, 10000000000000000ul);
            L_TABLE(18, 100000000000000000ul);
            L_TABLE(19, 1000000000000000000ul);
            L_TABLE(20, 10000000000000000000ul);
#undef L_TABLE
            switch (len)
            {
                default:
                    // Number is too short or too long
                    return false;

#ifdef L_CASE
    #error L_CASE already defined
#endif
#define L_CASE(n) \
    case n: l += lt_##n[*buf++ - '0']
                    L_CASE(20);
                    L_CASE(19);
                    L_CASE(18);
                    L_CASE(17);
                    L_CASE(16);
                    L_CASE(15);
                    L_CASE(14);
                    L_CASE(13);
                    L_CASE(12);
                    L_CASE(11);
                    L_CASE(10);
                    L_CASE(9);
                    L_CASE(8);
                    L_CASE(7);
                    L_CASE(6);
                    L_CASE(5);
                    L_CASE(4);
                    L_CASE(3);
                    L_CASE(2);
                    L_CASE(1);
#undef L_CASE
            }
            return true;
        }

        inline bool read(long &l, const char *buf, size_t len)
        {
            return read(l, buf, len, tmp::IntType<sizeof(long)>());
        }
    } // namespace priv

    // When ok, len is set to the number of chars used to read the integer
    inline bool read(long &l, const char *buf, size_t &len)
    {
        if (len == 0)
            return false;

        bool isNegative = false;
        if (*buf == '-')
        {
            isNegative = true;
            ++buf;
        }

        size_t s = 0;
        {
            auto b = buf;
            for (; s < len; ++s)
            {
                const unsigned char ch = (unsigned char)*b++;
                if (ch < '0' || ch > '9')
                    break;
            }
        }
        if (s == 0)
            return false;
        const auto res = priv::read(l, buf, s);
        if (res)
        {
            if (isNegative)
            {
                ++s;
                l = -l;
            }
            len = s;
        }
        return res;
    }

} // namespace rubr::parse::numbers

#endif

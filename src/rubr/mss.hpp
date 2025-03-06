#ifndef HEADER_rubr_mss_hpp_ALREADY_INCLUDED
#define HEADER_rubr_mss_hpp_ALREADY_INCLUDED

#include <optional>

namespace rubr { namespace mss {

    namespace detail {
        template<typename RC>
        struct Traits
        {
            static const RC Ok() { return RC::Ok; }
            static const RC Error() { return RC::Error; }
        };
        template<>
        struct Traits<bool>
        {
            static const bool Ok() { return true; }
            static const bool Error() { return false; }
        };
        template<>
        struct Traits<int>
        {
            static const int Ok() { return 0; }
            static const int Error() { return -1; }
        };
    } // namespace detail

    template<typename RC>
    RC ok_value()
    {
        return detail::Traits<RC>::Ok();
    }

    template<typename RC>
    bool is_ok(RC rc)
    {
        return rc == ok_value<RC>();
    }
    template<typename T>
    bool is_ok(const std::optional<T> &opt)
    {
        return !!opt;
    }

    template<typename T, typename RC>
    RC on_fail(T v, RC e)
    {
        if (is_ok(v))
            return ok_value<RC>();
        return e;
    }

    template<typename Dst, typename Src>
    void aggregate(Dst &dst, Src src)
    {
        if (!is_ok(src))
            dst = detail::Traits<Dst>::Error();
    }
    template<typename T>
    void aggregate(T &dst, T src)
    {
        dst = src;
    }

}} // namespace rubr::mss

#include <rubr/debug/log.hpp>
#include <rubr/macro/variadic.h>

// MSS_RC
#if defined(MSS_RC)
    #error MSS_BEGIN macros already defined
#endif
#define MSS_RC l_rubr_mss_rc_value

// MSS_BEGIN
#if defined(MSS_BEGIN) || defined(MSS_BEGIN_1) || defined(MSS_BEGIN_2)
    #error MSS_BEGIN macros already defined
#endif
#define MSS_BEGIN_1(rc_type)            \
    S(nullptr);                         \
    using l_rubr_mss_rc_type = rc_type; \
    l_rubr_mss_rc_type MSS_RC = rubr::mss::ok_value<l_rubr_mss_rc_type>()
#define MSS_BEGIN_2(rc_type, logns)     \
    S(logns);                           \
    using l_rubr_mss_rc_type = rc_type; \
    l_rubr_mss_rc_type MSS_RC = rubr::mss::ok_value<l_rubr_mss_rc_type>()
#define MSS_BEGIN(...) RUBR_GET_ARG_3((__VA_ARGS__, MSS_BEGIN_2, MSS_BEGIN_1))(__VA_ARGS__)

// MSS
#if defined(MSS) || defined(MSS_1) || defined(MSS_2) || defined(MSS_3)
    #error MSS macros already defined
#endif
#define MSS_1(expr)                                                                       \
    do {                                                                                  \
        rubr::mss::aggregate(MSS_RC, (expr));                                             \
        if (!rubr::mss::is_ok(MSS_RC))                                                    \
        {                                                                                 \
            S("MSS");                                                                     \
            L("Error: " #expr << " failed in \"" << __FILE__ << ":" << __LINE__ << "\""); \
            return MSS_RC;                                                                \
        }                                                                                 \
    } while (false)
#define MSS_2(expr, action)                                                               \
    do {                                                                                  \
        rubr::mss::aggregate(MSS_RC, (expr));                                             \
        if (!rubr::mss::is_ok(MSS_RC))                                                    \
        {                                                                                 \
            S("MSS");                                                                     \
            L("Error: " #expr << " failed in \"" << __FILE__ << ":" << __LINE__ << "\""); \
            action;                                                                       \
            return MSS_RC;                                                                \
        }                                                                                 \
    } while (false)
#define MSS_3(expr, action, aggregator)                                                   \
    do {                                                                                  \
        aggregator(MSS_RC, (expr));                                                       \
        if (!rubr::mss::is_ok(MSS_RC))                                                    \
        {                                                                                 \
            S("MSS");                                                                     \
            L("Error: " #expr << " failed in \"" << __FILE__ << ":" << __LINE__ << "\""); \
            action;                                                                       \
            return MSS_RC;                                                                \
        }                                                                                 \
    } while (false)
#define MSS(...) RUBR_GET_ARG_4((__VA_ARGS__, MSS_3, MSS_2, MSS_1))(__VA_ARGS__)

// MSS_Q
#if defined(MSS_Q) || defined(MSS_Q_1) || defined(MSS_Q_2) || defined(MSS_Q_3)
    #error MSS_Q macros already defined
#endif
#define MSS_Q_1(expr)                         \
    do {                                      \
        rubr::mss::aggregate(MSS_RC, (expr)); \
        if (!rubr::mss::is_ok(MSS_RC))        \
        {                                     \
            return MSS_RC;                    \
        }                                     \
    } while (false)
#define MSS_Q_2(expr, action)                 \
    do {                                      \
        rubr::mss::aggregate(MSS_RC, (expr)); \
        if (!rubr::mss::is_ok(MSS_RC))        \
        {                                     \
            action;                           \
            return MSS_RC;                    \
        }                                     \
    } while (false)
#define MSS_Q_3(expr, action, aggregator) \
    do {                                  \
        aggregator(MSS_RC, (expr));       \
        if (!rubr::mss::is_ok(MSS_RC))    \
        {                                 \
            action;                       \
            return MSS_RC;                \
        }                                 \
    } while (false)
#define MSS_Q(...) RUBR_GET_ARG_4((__VA_ARGS__, MSS_Q_3, MSS_Q_2, MSS_Q_1))(__VA_ARGS__)

// MSS_END
#if defined(MSS_END)
    #error MSS_END macros already defined
#endif
#define MSS_END() return MSS_RC

// MSS_RETURN_OK
#if defined(MSS_RETURN_OK)
    #error MSS_RETURN_OK macros already defined
#endif
#define MSS_RETURN_OK() return MSS_RC

#endif

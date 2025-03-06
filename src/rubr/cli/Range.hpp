#ifndef HEADER_rubr_cli_Range_hpp_ALREADY_INCLUDED
#define HEADER_rubr_cli_Range_hpp_ALREADY_INCLUDED

#include <charconv>
#include <concepts>
#include <cstring>
#include <optional>
#include <string>

namespace rubr { namespace cli {

    class Range
    {
    public:
        template<typename Int>
        Range(Int argc, const char **argv)
            : argc_(argc), argv_(argv)
        {}

        bool pop(std::string &str);
        bool pop(bool &b);

        template<std::integral T>
        bool pop(T &v)
        {
            if (argix_ >= argc_)
                return false;

            const char *arg = argv_[argix_];
            const auto size = std::strlen(arg);

            auto res = std::from_chars(arg, arg + size, v);
            if (res.ptr == arg)
                return false;

            ++argix_;

            return true;
        }

        template<typename T>
        bool pop(std::optional<T> &opt)
        {
            if (argix_ >= argc_)
                return false;
            opt.emplace();
            return pop(*opt);
        }

    private:
        const unsigned int argc_;
        const char **const argv_;
        unsigned int argix_ = 0;
    };

}} // namespace rubr::cli

#endif

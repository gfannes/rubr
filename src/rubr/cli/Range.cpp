#include <rubr/cli/Range.hpp>

#include <cstring>

namespace rubr { namespace cli {

    bool Range::pop(std::string &str)
    {
        if (argix_ >= argc_)
            return false;
        str = argv_[argix_++];
        return true;
    }

    bool Range::pop(bool &b)
    {
        if (argix_ >= argc_)
            return false;

        auto is = [&](const char *wanted) {
            return std::strcmp(argv_[argix_], wanted) == 0;
        };

        b = (false || is("y") || is("yes") || is("1") || is("true"));

        ++argix_;

        return true;
    }

}} // namespace rubr::cli

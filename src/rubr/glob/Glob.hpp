#ifndef HEADER_rubr_glob_Glob_hpp_ALREADY_INCLUDED
#define HEADER_rubr_glob_Glob_hpp_ALREADY_INCLUDED

#include <string>
#include <vector>

namespace rubr::glob {

    enum class Wildcard
    {
        Nothing,
        Some,
        All,
    };

    Wildcard max(Wildcard a, Wildcard b);

    class Glob
    {
    public:
        struct Config
        {
            Wildcard front = Wildcard::Nothing;
            std::string pattern;
            Wildcard back = Wildcard::Nothing;
        };

        Glob(const Config &config);

        bool operator()(const std::string_view &str) const;

    private:
        bool match_(std::size_t part_ix, const std::string_view &sv) const;
        bool match_(Wildcard wildcard, const std::string_view &sv) const;

        struct Part
        {
            Wildcard wildcard = Wildcard::Nothing;
            std::string str;
        };
        std::vector<Part> parts_;
    };

} // namespace rubr::glob

#endif

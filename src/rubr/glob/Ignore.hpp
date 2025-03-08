#ifndef HEADER_rubr_glob_Ignore_hpp_ALREADY_INCLUDED
#define HEADER_rubr_glob_Ignore_hpp_ALREADY_INCLUDED

#include <rubr/glob/Glob.hpp>

#include <filesystem>
#include <string>
#include <vector>

namespace rubr::glob {

    class Ignore
    {
    public:
        bool load_from_file(const std::filesystem::path &fp);
        bool load_from_content(const std::string &content);

        bool operator()(const std::string_view &fp) const;

    private:
        std::vector<Glob> ignores_;
        std::vector<Glob> includes_;
    };

} // namespace rubr::glob

#endif

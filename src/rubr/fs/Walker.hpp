#ifndef HEADER_rubr_fs_Walker_hpp_ALREADY_INCLUDED
#define HEADER_rubr_fs_Walker_hpp_ALREADY_INCLUDED

#include <rubr/fs/util.hpp>
#include <rubr/glob/Ignore.hpp>
#include <rubr/mss.hpp>

#include <filesystem>
#include <type_traits>
#include <vector>

namespace rubr::fs {

    class Walker
    {
    public:
        struct Config
        {
            std::filesystem::path basedir;
            bool include_hidden = false;
        };

        Walker(const Config &config)
            : config_(config) {}

        template<typename Ftor, typename ReturnCode = std::invoke_result_t<Ftor, const std::filesystem::path &>>
        ReturnCode operator()(Ftor &&ftor)
        {
            MSS_BEGIN(ReturnCode, "");
            MSS(call_(config_.basedir, ftor));
            MSS_END();
        }

    private:
        template<typename Ftor, typename ReturnCode = std::invoke_result_t<Ftor, const std::filesystem::path &>>
        ReturnCode call_(const std::filesystem::path &dir, Ftor &&ftor)
        {
            MSS_BEGIN(ReturnCode);

            L(C(dir));

            bool added_ignore = false;

            for (const auto &filename : {".gitignore"})
            {
                static std::filesystem::path fp;
                fp = dir;
                fp /= filename;

                if (std::filesystem::is_regular_file(fp))
                {
                    L("Found ignore file " << fp);
                    auto &ignore = ignore_stack_.emplace_back();
                    ignore.basedir_size = dir.native().size();
                    MSS(ignore.ignore.load_from_file(fp));
                    added_ignore = true;
                    break;
                }
            }

            // Add a dummy ignore, if needed.
            if (ignore_stack_.empty())
            {
                auto &ignore = ignore_stack_.emplace_back();
                ignore.basedir_size = dir.native().size();
                added_ignore = true;
            }

            // &perf: Using readdir() is expected to be 10x faster
            for (const auto &dir_entry : std::filesystem::directory_iterator(dir))
            {
                const auto &ignore = ignore_stack_.back();
                
                const auto &fullpath = dir_entry.path();
                const std::string_view fullpath_sv = fullpath.native();
                const std::string_view relpath = fullpath_sv.substr(ignore.basedir_size+1);
                L(C(relpath));

                if (!config_.include_hidden && rubr::fs::is_hidden(relpath))
                {
                    L("Skipping hidden path " << fullpath);
                    continue;
                }

                if (ignore.ignore(relpath))
                {
                    L("Skipping ignored path " << fullpath);
                    continue;
                }

                if (dir_entry.is_regular_file())
                {
                    L("Found regular file " << fullpath);
                    MSS(ftor(fullpath));
                }
                else if (dir_entry.is_directory())
                {
                    L("Found directory " << fullpath);
                    MSS(call_(fullpath, ftor));
                }
            }

            if (added_ignore)
                ignore_stack_.pop_back();

            MSS_END();
        }

        const Config config_;
        struct Ignore
        {
            rubr::glob::Ignore ignore;
            std::size_t basedir_size = 0;
        };
        std::vector<Ignore> ignore_stack_;
    };

} // namespace rubr::fs

#endif

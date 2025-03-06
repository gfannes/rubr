#ifndef HEADER_rubr_fs_Walker_hpp_ALREADY_INCLUDED
#define HEADER_rubr_fs_Walker_hpp_ALREADY_INCLUDED

#include <rubr/mss.hpp>
#include <rubr/fs/util.hpp>

#include <filesystem>
#include <type_traits>

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
        ReturnCode operator()(Ftor &&ftor) const
        {
            return call_(config_.basedir, ftor);
        }

    private:
        template<typename Ftor, typename ReturnCode = std::invoke_result_t<Ftor, const std::filesystem::path &>>
        ReturnCode call_(const std::filesystem::path &dir, Ftor &&ftor) const
        {
            MSS_BEGIN(ReturnCode);

            for (const auto dir_entry : std::filesystem::directory_iterator(dir))
            {
                const auto &path = dir_entry.path();

                if (!config_.include_hidden && rubr::fs::is_hidden(path))
                    continue;

                if (dir_entry.is_regular_file())
                    MSS(ftor(dir_entry.path()));
                else if (dir_entry.is_directory())
                    MSS(call_(dir_entry.path(), ftor));
            }

            MSS_END();
        }
        const Config config_;
    };

} // namespace rubr::fs

#endif

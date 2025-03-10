#include <rubr/glob/Ignore.hpp>

#include <rubr/fs/util.hpp>
#include <rubr/mss.hpp>
#include <rubr/parse/Strange.hpp>

namespace rubr::glob {

    bool Ignore::load_from_file(const std::filesystem::path &fp)
    {
        MSS_BEGIN(bool);
        std::string content;
        MSS(rubr::fs::read(content, fp));
        MSS(load_from_content(content));
        MSS_END();
    }

    bool Ignore::load_from_content(const std::string &content)
    {
        MSS_BEGIN(bool);
        L(C(this)C(ignores_.size()) C(includes_.size()));

        const std::string whitespace = " ";

        rubr::parse::Strange strange(content);
        for (rubr::parse::Strange line; strange.pop_line(line);)
        {
            L(C(line.str()));
            line.strip_left(whitespace);
            line.strip_right(whitespace);

            if (line.pop_if('#'))
                continue;

            auto &dst = line.pop_if('!') ? includes_ : ignores_;

            if (line.empty())
                continue;

            rubr::glob::Glob::Config config;
            config.front = line.pop_if('/') ? rubr::glob::Wildcard::Nothing : rubr::glob::Wildcard::All;
            config.pattern = line.str();
            config.back = line.back() == '/' ? rubr::glob::Wildcard::All : rubr::glob::Wildcard::Nothing;

            dst.emplace_back(config);
        }

        L(C(this)C(ignores_.size()) C(includes_.size()));

        MSS_END();
    }

    bool Ignore::operator()(const std::string_view &fp) const
    {
        S(nullptr);
        L(C(this)C(ignores_.size()) C(includes_.size()));

        bool do_ignore = false;

        for (const auto &ignore_glob : ignores_)
        {
            L(C(&ignore_glob));
            if (ignore_glob(fp))
            {
                do_ignore = true;
                break;
            }
        }

        if (do_ignore)
        {
            for (const auto &include_glob : includes_)
            {
                L(C(&include_glob));
                if (include_glob(fp))
                {
                    do_ignore = false;
                    break;
                }
            }
        }

        return do_ignore;
    }

} // namespace rubr::glob

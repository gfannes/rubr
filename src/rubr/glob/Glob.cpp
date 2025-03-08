#include <rubr/debug/log.hpp>
#include <rubr/glob/Glob.hpp>

#include <algorithm>
#include <cassert>

namespace rubr::glob {

    Wildcard max(Wildcard a, Wildcard b)
    {
        return Wildcard(std::max(int(a), int(b)));
    }

    Glob::Glob(const Config &config)
    {
        if (config.pattern.empty())
        {
            parts_.push_back(Part{.wildcard = max(config.front, config.back), .str = ""});
            return;
        }

        // Split config.pattern on '*' and convert to Parts
        const std::string_view pattern = config.pattern;
        Wildcard wildcard = config.front;
        for (std::size_t search_pos = 0, ix; search_pos < pattern.size(); search_pos = ix + 1)
        {
            ix = pattern.find('*', search_pos);

            if (ix == std::string_view::npos)
            {
                // No wildcard found: add this part and stop
                parts_.push_back(Part{.wildcard = wildcard, .str = std::string(pattern.substr(search_pos))});
                wildcard = Wildcard::Nothing;
                break;
            }

            if (ix == search_pos)
            {
                // We found a wildcard at the start, merge it with the one already present
                wildcard = max(wildcard, Wildcard::Some);
            }
            else
            {
                // We found a non-wildcard at the start
                parts_.push_back(Part{.wildcard = wildcard, .str = std::string(pattern.substr(search_pos, ix - search_pos))});
                wildcard = Wildcard::Some;
            }

            // Upgrade the wildcard if more '*'s are present
            while (ix + 1 < pattern.size() && pattern[ix + 1] == '*')
            {
                wildcard = Wildcard::All;
                ++ix;
            }
        }

        // Add the last empty part
        parts_.push_back(Part{.wildcard = max(wildcard, config.back), .str = ""});

        S(nullptr);
        for (const auto &part : parts_)
        {
            L(C(part.wildcard, int) C(part.str));
        }
    }

    bool Glob::operator()(const std::string_view &str) const
    {
        S(nullptr);
        L(C(this)C(str));
        return match_(0, str);
    }

    bool Glob::match_(std::size_t part_ix, const std::string_view &sv) const
    {
        S(nullptr);
        L(C(part_ix) C(sv) C(parts_.size()));

        if (part_ix >= parts_.size())
        {
            L("No more parts to match: done");
            return true;
        }

        const Part &part = parts_[part_ix];

        if (part.str.empty())
        {
            // Empty part.str is a special case that should only occur at the end
            assert(part_ix + 1 == parts_.size());
            return match_(part.wildcard, sv);
        }

        for (std::size_t search_pos = 0, ix; search_pos < sv.size(); search_pos = ix + 1)
        {
            ix = sv.find(part.str, search_pos);
            if (ix == std::string_view::npos)
                break;

            if (match_(part.wildcard, sv.substr(0, ix)) && match_(part_ix + 1, sv.substr(ix + part.str.size())))
                return true;
        }

        return false;
    }

    bool Glob::match_(Wildcard wildcard, const std::string_view &sv) const
    {
        bool ret = false;
        switch (wildcard)
        {
            case Wildcard::Nothing: ret = sv.empty(); break;
            case Wildcard::Some: ret = !sv.contains('/'); break;
            case Wildcard::All: ret = true; break;
        }
        S(nullptr);
        L(C(wildcard, int) C(sv) C(ret));
        return ret;
    }

} // namespace rubr::glob

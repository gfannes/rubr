#ifndef HEADER_rubr_fs_util_hpp_ALREADY_INCLUDED
#define HEADER_rubr_fs_util_hpp_ALREADY_INCLUDED

#include <rubr/mss.hpp>

#include <cassert>
#include <filesystem>
#include <fstream>
#include <string>

namespace rubr::fs {

    inline bool is_hidden(const std::filesystem::path &path)
    {
        if (path.has_filename())
        {
            // &perf: use custom allocator into a thread_local buffer of size max of filepath to avoid allocations
            const auto filename = path.filename().native();
            if (filename.empty())
                return false;
            return filename[0] == '.';
        }

        const auto parent = path.parent_path().filename().native();
        if (parent.empty())
            return false;
        return parent[0] == '.';
    }

    // Seems to have the same performance
#if 0
    inline bool is_hidden(std::string_view path)
    {
        while (true)
        {
            const auto ix = path.find('/');
            if (ix == std::string_view::npos || ix == path.size() - 1)
                break;
            path = path.substr(ix + 1);
        }

        if (path.empty())
            return false;

        return path[0] == '.';
    }
#else
    inline bool is_hidden(std::string_view path)
    {
        S(nullptr);

        auto ix = path.rfind('/');
        L(C(path) C(ix));

        if (ix != std::string_view::npos)
        {
            if (ix + 1 == path.size())
            {
                L("Found '/' at the end");
                if (ix == 0)
                {
                    L("path is exactly '/'");
                    return false;
                }
                L("Search again to support paths with trailing '/', eg, '/home/geertf/.config/'");
                ix = path.rfind('/', ix - 1);
            }
        }

        if (ix == std::string_view::npos)
        {
            L("No '/' found: check for a '.' at the start of path");
            return !path.empty() && path.front() == '.';
        }

        assert(ix + 1 < path.size());
        return path[ix + 1] == '.';
    }
#endif

    inline bool read(std::string &content, const std::filesystem::path &fp)
    {
        MSS_BEGIN(bool);

        std::ifstream fi(fp, std::ios::binary | std::ios::ate);
        MSS(fi.good());

        const auto end_pos = fi.tellg();
        fi.seekg(0);
        const std::size_t size = end_pos - fi.tellg();

        content.resize_and_overwrite(size, [](auto buffer, auto size) { return size; });
        fi.read(&content[0], size);

        MSS_END();
    }

    inline std::filesystem::path expand_path(const std::string_view &sv)
    {
        if (sv == "~")
        {
            if (const auto home = std::getenv("HOME"); !!home)
                return std::filesystem::path(home);
        }
        else if (sv.starts_with("~/"))
        {
            if (const auto home = std::getenv("HOME"); !!home)
                return std::filesystem::path(home) / sv.substr(2);
        }
        return sv;
    }

} // namespace rubr::fs

#endif

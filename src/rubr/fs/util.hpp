#ifndef HEADER_rubr_fs_util_hpp_ALREADY_INCLUDED
#define HEADER_rubr_fs_util_hpp_ALREADY_INCLUDED

#include <filesystem>

namespace rubr::fs {

    inline bool is_hidden(const std::filesystem::path &path)
    {
        const auto filename = path.filename().string();
        if (filename.empty())
            return false;
        return filename[0] == '.';
    }

} // namespace rubr::fs

#endif

#ifndef HEADER_rubr_tmp_IntType_hpp_ALREADY_INCLUDED
#define HEADER_rubr_tmp_IntType_hpp_ALREADY_INCLUDED

namespace rubr::tmp {

    template<int v>
    struct IntType
    {
        enum : int
        {
            value = v
        };
    };

} // namespace rubr::tmp

#endif

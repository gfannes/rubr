#ifndef HEADER_rubr_ix_Range_hpp_ALREADY_INCLUDED
#define HEADER_rubr_ix_Range_hpp_ALREADY_INCLUDED

#include <rubr/ix/ReverseRange.hpp>

#include <cstddef>
#include <optional>
#include <ostream>

namespace rubr::ix {

    class Range
    {
    public:
        using Ix = std::size_t;
        using Size = std::size_t;

        Range() {}
        Range(Ix start_ix, Size size)
            : begin_(start_ix), end_(start_ix + size) {}

        bool operator==(const Range &rhs) const { return begin_ == rhs.begin_ && end_ == rhs.end_; }
        bool operator!=(const Range &rhs) const { return !operator==(rhs); }

        Ix start() const { return begin_; }
        Ix stop() const { return end_; }

        struct Iterator
        {
            Ix ix;
            Iterator(Ix ix)
                : ix(ix) {}
            bool operator==(const Iterator &rhs) const { return ix == rhs.ix; }
            bool operator!=(const Iterator &rhs) const { return ix != rhs.ix; }
            Ix operator*() const { return ix; }
            Iterator &operator++()
            {
                ++ix;
                return *this;
            }
        };

        Iterator begin() const { return Iterator{begin_}; }
        Iterator end() const { return Iterator{end_}; }
        Size size() const { return end_ - begin_; }
        bool empty() const { return end_ == begin_; }

        bool contains(Ix ix) const { return begin_ <= ix && ix < end_; }

        void clear() { *this = Range(); }

        Ix ix(Ix offset) const { return begin_ + offset; }
        Ix operator[](Ix offset) const { return ix(offset); }

        void init(Ix start_ix, Ix size)
        {
            begin_ = start_ix;
            end_ = begin_ + size;
        }

        void push_back(Ix size)
        {
            end_ += size;
        }
        void resize(Ix size)
        {
            end_ = begin_ + size;
        }

        template<typename Ftor, typename... Data>
        void each(Ftor &&ftor, Data &&...data) const
        {
            for (auto ix = begin_; ix != end_; ++ix) ftor(data[ix]...);
        }

        // ix starts from begin()
        template<typename Ftor>
        void each_index(Ftor &&ftor) const
        {
            for (auto ix = begin_; ix != end_; ++ix) ftor(ix);
        }
        template<typename Ftor, typename... Data>
        void each_with_index(Ftor &&ftor, Data &&...data) const
        {
            for (auto ix = begin_; ix != end_; ++ix) ftor(data[ix]..., ix);
        }

        // ix starts from 0
        template<typename Ftor>
        void each_offset(Ftor &&ftor) const
        {
            const auto s = size();
            for (auto ix = 0u; ix != s; ++ix) ftor(ix);
        }
        template<typename Ftor, typename... Data>
        void each_with_offset(Ftor &&ftor, Data &&...data) const
        {
            const auto s = size();
            for (auto ix = 0u; ix != s; ++ix) ftor(data[begin_ + ix]..., ix);
        }

        ReverseRange reverse() const { return ReverseRange(begin_, end_); }

    private:
        Ix begin_ = 0u;
        Ix end_ = 0u;
    };

    using Range_opt = std::optional<Range>;

    inline std::ostream &operator<<(std::ostream &os, const Range &range)
    {
        return os << "[" << range.start() << "; " << range.size() << "]";
    }

    inline Range make_range(std::size_t size)
    {
        return Range(0, size);
    }

} // namespace rubr::ix

#endif

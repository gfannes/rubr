#ifndef HEADER_rubr_ix_ReverseRange_hpp_ALREADY_INCLUDED
#define HEADER_rubr_ix_ReverseRange_hpp_ALREADY_INCLUDED

#include <cstddef>

namespace rubr::ix {

    // Can only be used in range-based for
    class ReverseRange
    {
    public:
        using Ix = std::size_t;

        ReverseRange(Ix begin, Ix end)
            : begin_(begin), end_(end) {}

        class Iterator
        {
        public:
            Iterator(Ix ix)
                : ix_(ix) {}
            bool operator==(const Iterator &rhs) const { return ix_ == rhs.ix_; }
            bool operator!=(const Iterator &rhs) const { return ix_ != rhs.ix_; }
            Ix operator*() const { return ix_ - 1; }
            Iterator &operator++()
            {
                --ix_;
                return *this;
            }

        private:
            Ix ix_;
        };

        Iterator begin() const { return Iterator{end_}; }
        Iterator end() const { return Iterator{begin_}; }

    private:
        Ix begin_ = 0u;
        Ix end_ = 0u;
    };

} // namespace rubr::ix

#endif

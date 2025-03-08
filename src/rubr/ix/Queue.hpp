#ifndef HEADER_rubr_ix_Queue_hpp_ALREADY_INCLUDED
#define HEADER_rubr_ix_Queue_hpp_ALREADY_INCLUDED

#include <cassert>
#include <cstddef>
#include <optional>

namespace rubr::ix {

    class Queue
    {
    public:
        void init(std::size_t capacity)
        {
            capacity_ = capacity;
            pop_ix_ = {};
            size_ = {};
        }

        std::size_t size() const { return size_; }
        std::size_t capacity() const { return capacity_; }

        bool empty() const { return size_ == 0; }
        bool full() const { return size_ == capacity_; }

        std::optional<std::size_t> push()
        {
            if (full())
                return {};
            return canon_(pop_ix_ + size_++);
        }

        std::optional<std::size_t> pop()
        {
            if (empty())
                return {};
            --size_;
            const auto ix = pop_ix_;
            pop_ix_ = canon_(pop_ix_ + 1);
            return ix;
        }

    private:
        std::size_t canon_(std::size_t ix) const
        {
            const auto ret = ix >= capacity_ ? ix - capacity_ : ix;
            assert(ret < capacity_);
            return ret;
        }

        std::size_t pop_ix_{};
        std::size_t size_{};
        std::size_t capacity_{};
    };

} // namespace rubr::ix

#endif

#include <rubr/parse/Strange.hpp>
#include <rubr/debug/log.hpp>

#include <cassert>

namespace rubr::parse {

    Strange::Strange()
        : b_(0), s_(0), l_(0)
    {
    }
    Strange::Strange(const std::string &str)
        : b_(str.data()), s_(str.data()), l_(str.size())
    {
    }
    Strange::Strange(const char *buffer, size_t len)
        : b_(buffer), s_(buffer), l_(len)
    {
    }

    Strange::Strange(const Strange &rhs)
        : b_(rhs.b_), s_(rhs.s_), l_(rhs.l_)
    {
    }

    Strange &Strange::operator=(const Strange &rhs)
    {
        b_ = rhs.b_;
        s_ = rhs.s_;
        l_ = rhs.l_;
        return *this;
    }
    Strange &Strange::operator=(const std::string &str)
    {
        b_ = str.data();
        s_ = str.data();
        l_ = str.size();
        return *this;
    }

    bool Strange::empty() const
    {
        return l_ == 0;
    }
    size_t Strange::size() const
    {
        return l_;
    }
    std::string Strange::str() const
    {
        return std::string(s_, l_);
    }
    char Strange::front() const
    {
        assert(s_ && l_);
        return *s_;
    }
    char Strange::back() const
    {
        assert(s_ && l_);
        return s_[l_ - 1];
    }
    char Strange::operator[](std::size_t ix) const
    {
        assert(s_ && ix < l_);
        return s_[ix];
    }

    void Strange::clear()
    {
        s_ = 0;
        l_ = 0;
    }

    bool Strange::contains(char ch) const
    {
        return nullptr != std::memchr(s_, ch, l_);
    }

    unsigned int Strange::strip_left(char ch)
    {
        unsigned int count = 0;
        for (; !empty(); pop_front())
        {
            if (front() != ch)
                break;
            ++count;
        }
        return count;
    }
    unsigned int Strange::strip_left(const std::string &chars)
    {
        unsigned int count = 0;
        for (; !empty(); pop_front())
        {
            if (chars.find(front()) == std::string::npos)
                break;
            ++count;
        }
        return count;
    }

    unsigned int Strange::strip_right(char ch)
    {
        unsigned int count = 0;
        for (; !empty(); pop_back())
        {
            if (back() != ch)
                break;
            ++count;
        }
        return count;
    }
    unsigned int Strange::strip_right(const std::string &chars)
    {
        unsigned int count = 0;
        for (; !empty(); pop_back())
        {
            if (chars.find(back()) == std::string::npos)
                break;
            ++count;
        }
        return count;
    }

    bool Strange::pop_bracket(Strange &res, const std::string &oc)
    {
        if (oc.size() != 2)
            return false;
        const auto o = oc[0];
        const auto c = oc[1];
        if (!pop_if(o))
            return false;
        Strange sp = *this;
        for (unsigned int level = 1; !empty(); pop_front())
        {
            const auto ch = front();
            if (ch == o)
            {
                ++level;
            }
            else if (ch == c)
            {
                --level;
                if (level == 0)
                {
                    res.s_ = sp.s_;
                    res.l_ = s_ - res.s_;
                    pop_front();
                    return true;
                }
            }
        }
        *this = sp;
        return false;
    }
    bool Strange::pop_bracket(std::string &res, const std::string &oc)
    {
        Strange strange;
        if (!pop_bracket(strange, oc))
            return false;
        strange.pop_all(res);
        return true;
    }
    bool Strange::pop_bracket(const std::string &oc)
    {
        Strange tmp;
        return pop_bracket(tmp, oc);
    }

    bool Strange::pop_all(Strange &res)
    {
        assert(invariants_());
        res = *this;
        clear();
        return !res.empty();
    }
    bool Strange::pop_all(std::string &res)
    {
        assert(invariants_());
        Strange s;
        pop_all(s);
        res = s.str();
        return !res.empty();
    }
    // Does not pop ch
    bool Strange::pop_to(Strange &res, const char ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        char *ptr = (char *)std::memchr(s_, ch, l_);
        if (!ptr)
            return false;
        res.s_ = s_;
        res.l_ = ptr - s_;
        forward_(res.l_);
        return true;
    }
    bool Strange::pop_to(const char ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        char *ptr = (char *)std::memchr(s_, ch, l_);
        if (!ptr)
            return false;
        forward_(ptr - s_);
        return true;
    }
    // Does not pop str
    bool Strange::pop_to(Strange &res, const std::string &str)
    {
        assert(invariants_());
        if (str.empty())
            return false;
        // We will iteratively search for ch, and try to match the rest of str
        const char ch = str[0];
        const size_t s = str.size();
        const Strange sp = *this;
        while (char *ptr = (char *)std::memchr(s_, ch, l_))
        {
            const size_t l = ptr - s_;
            forward_(l);
            if (size() < s)
                break;
            if (0 == std::memcmp(str.data(), s_, s))
            {
                // We found a match at this location
                res.s_ = sp.s_;
                res.l_ = s_ - res.s_;
                return true;
            }
            else
            {
                // No full match was found, we forward to the next character and try again
                forward_(1);
            }
        }
        *this = sp;
        return false;
    }
    bool Strange::pop_to_any(Strange &res, const std::string &str)
    {
        assert(invariants_());
        if (empty())
            return false;
        for (size_t i = 0; i < l_; ++i)
            if (str.find(s_[i]) != std::string::npos)
            {
                res.s_ = s_;
                res.l_ = i;
                forward_(i);
                return true;
            }

        return false;
    }
    bool Strange::pop_to_any(std::string &res, const std::string &str)
    {
        Strange s;
        if (!pop_to_any(s, str))
            return false;
        res = s.str();
        return true;
    }
    bool Strange::diff_to(const Strange &strange)
    {
        if (empty())
            // Already at the end
            return false;
        if (strange.empty())
            // If strange is empty, we cannot trust its s_. We assume strange ran to its end and will return everything in res.
            return true;
        if (strange.s_ < s_)
            // Not really expected
            return false;
        l_ = (strange.s_ - s_);
        return true;
    }
    // Pops ch too, set inclusive to true if you want ch to be included in res
    bool Strange::pop_until(Strange &res, const char ch, bool inclusive)
    {
        assert(invariants_());
        if (empty())
            return false;
        for (size_t i = 0; i < l_; ++i)
            if (s_[i] == ch)
            {
                res.s_ = s_;
                res.l_ = i + (inclusive ? 1 : 0);
                forward_(i + 1);
                return true;
            }

        return false;
    }
    bool Strange::pop_until(std::string &res, const char ch, bool inclusive)
    {
        Strange s;
        if (!pop_until(s, ch, inclusive))
            return false;
        res = s.str();
        return true;
    }
    bool Strange::pop_until(Strange &res, const std::string &str, bool inclusive)
    {
        assert(invariants_());
        if (str.empty())
            return true;
        const size_t s = str.size();
        if (size() < s)
            // We are to small to match str
            return false;
        const auto ch = str.front();
        const auto l2check = l_ - s + 1;
        for (size_t i = 0; i < l2check; ++i)
            if (s_[i] == ch)
            {
                // Pontential match, check the rest of str
                if (!std::memcmp(str.data(), s_ + i, s))
                {
                    res.s_ = s_;
                    res.l_ = i + (inclusive ? s : 0);
                    forward_(i + s);
                    return true;
                }
            }
        return false;
    }
    bool Strange::pop_until(std::string &res, const std::string &str, bool inclusive)
    {
        Strange s;
        if (!pop_until(s, str, inclusive))
            return false;
        res = s.str();
        return true;
    }
    bool Strange::pop_until(const char ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        for (size_t i = 0; i < l_; ++i)
            if (s_[i] == ch)
            {
                forward_(i + 1);
                return true;
            }

        return false;
    }
    bool Strange::pop_until_any(Strange &res, const std::string &str, bool inclusive)
    {
        assert(invariants_());
        if (empty())
            return false;
        for (size_t i = 0; i < l_; ++i)
            if (str.find(s_[i]) != std::string::npos)
            {
                res.s_ = s_;
                res.l_ = i + (inclusive ? 1 : 0);
                forward_(i + 1);
                return true;
            }

        return false;
    }
    bool Strange::pop_until_any(std::string &res, const std::string &str, bool inclusive)
    {
        Strange s;
        if (!pop_until_any(s, str, inclusive))
            return false;
        res = s.str();
        return true;
    }
    bool Strange::pop_decimal(long &res)
    {
        assert(invariants_());
        if (empty())
            return false;
        size_t l = l_;
        if (!parse::numbers::read(res, s_, l))
            return false;
        forward_(l);
        return true;
    }
    bool Strange::pop_float(double &res)
    {
        assert(invariants_());
        if (empty())
            return false;
        char *e = 0;
        double d = std::strtod(s_, &e);
        if (e == s_)
            return false;
        res = d;
        forward_(e - s_);
        return true;
    }
    bool Strange::pop_float(float &res)
    {
        assert(invariants_());
        if (empty())
            return false;
        char *e = 0;
        float d = std::strtof(s_, &e);
        if (e == s_)
            return false;
        res = d;
        forward_(e - s_);
        return true;
    }

    bool Strange::pop_if(const char ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        if (*s_ != ch)
            return false;
        forward_(1);
        return true;
    }
    bool Strange::pop_if_any(const std::string &str)
    {
        assert(invariants_());
        if (empty())
            return false;
        const auto ix = str.find(*s_);
        if (ix == std::string::npos)
            return false;
        forward_(1);
        return true;
    }
    bool Strange::pop_back_if(const char ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        if (s_[l_ - 1] != ch)
            return false;
        shrink_(1);
        return true;
    }
    bool Strange::pop_front()
    {
        assert(invariants_());
        if (empty())
            return false;
        forward_(1);
        return true;
    }
    bool Strange::pop_back()
    {
        assert(invariants_());
        if (empty())
            return false;
        shrink_(1);
        return true;
    }
    bool Strange::pop_char(char &ch)
    {
        assert(invariants_());
        if (empty())
            return false;
        ch = *s_;
        forward_(1);
        return true;
    }

    bool Strange::pop_string(std::string &str, size_t nr)
    {
        assert(invariants_());
        if (l_ < nr)
            return false;
        str.assign(s_, nr);
        forward_(nr);
        return true;
    }
    bool Strange::pop_if(const std::string &str)
    {
        assert(invariants_());
        const auto s = str.size();
        if (l_ < s)
            return false;
        if (std::memcmp(str.data(), s_, s))
            return false;
        forward_(s);
        return true;
    }

    bool Strange::starts_with(const char ch) const
    {
        assert(invariants_());
        if (empty())
            return false;
        if (*s_ != ch)
            return false;
        return true;
    }
    bool Strange::starts_with(const std::string &str) const
    {
        assert(invariants_());
        const auto s = str.size();
        if (l_ < s)
            return false;
        if (std::memcmp(str.data(), s_, s))
            return false;
        return true;
    }

    bool Strange::pop_line(Strange &line, Strange &end)
    {
        S(nullptr);
        assert(invariants_());

        line.clear();

        if (empty())
            return false;

        line.s_ = s_;


        // We start looking for 0xa because that is the most likely indicator of an end-of-line
        // 0xd can occur on its own, but that is old-mac style, which is not used anymore
        const char *ptr = (const char *)std::memchr(s_, '\x0a', l_);
        if (!ptr)
        {
            L("No 0xa found, lets look for a 0xd (old-mac)");
            ptr = (const char *)std::memchr(s_, '\x0d', l_);
            if (!ptr)
            {
                L("old-mac wasn't found either, we return everything we got, this is the last line");
                line.l_ = l_;
                end.l_ = 0;
            }
            else
            {
                L("An old-mac end-of-line was found");
                line.l_ = ptr - s_;
                end.l_ = 1;
            }
        }
        else
        {
            L("0xa was found, we still need to determine if it is a unix or dos style end-of-line");
            if (ptr == s_)
            {
                L("This is an empty line, it does not make sense to check for 0xd");
                line.l_ = 0;
                end.l_ = 1;
            }
            else
            {
                L("We have to check for 0xd");
                if (ptr[-1] == '\x0d')
                {
                    L("This line is dos-style terminated");
                    line.l_ = ptr - s_ - 1;
                    end.l_ = 2;
                }
                else
                {
                    L("No 0xd was found before ptr so we have a unix-style terminated line");
                    line.l_ = ptr - s_;
                    end.l_ = 1;
                }
            }
        }

        end.s_ = s_ + line.l_;
        forward_(line.l_ + end.l_);

        return true;
    }
    bool Strange::pop_line(Strange &line)
    {
        Strange end;
        return pop_line(line, end);
    }
    bool Strange::pop_line(std::string &line)
    {
        Strange l;
        const bool b = pop_line(l);
        line = l.str();
        return b;
    }

    template<typename T>
    bool Strange::pop_lsb_(T &v)
    {
        assert(invariants_());
        if (l_ < sizeof(v))
            return false;
        v = 0;
        for (unsigned int i = 0; i < sizeof(v); ++i)
        {
            T tmp = *(const T *)(s_ + i);
            tmp <<= i * 8;
            v |= tmp;
        }
        forward_(sizeof(v));
        return true;
    }
    bool Strange::pop_lsb(std::uint8_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::uint16_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::uint32_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::uint64_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::int8_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::int16_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::int32_t &v) { return pop_lsb_(v); }
    bool Strange::pop_lsb(std::int64_t &v) { return pop_lsb_(v); }

    template<typename T>
    bool Strange::pop_msb_(T &v)
    {
        assert(invariants_());
        if (l_ < sizeof(v))
            return false;
        v = 0;
        for (unsigned int i = 0; i < sizeof(v); ++i)
        {
            if constexpr (sizeof(v) > 1)
                v <<= 8;
            v |= *(std::uint8_t *)(s_ + i);
        }
        forward_(sizeof(v));
        return true;
    }
    bool Strange::pop_msb(std::uint8_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::uint16_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::uint32_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::uint64_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::int8_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::int16_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::int32_t &v) { return pop_msb_(v); }
    bool Strange::pop_msb(std::int64_t &v) { return pop_msb_(v); }

    bool Strange::pop_count(size_t nr)
    {
        if (l_ < nr)
            return false;
        forward_(nr);
        return true;
    }
    bool Strange::pop_count(Strange &res, size_t nr)
    {
        if (l_ < nr)
            return false;
        res.s_ = s_;
        res.l_ = nr;
        forward_(nr);
        return true;
    }
    bool Strange::pop_count(std::string &str, size_t nr)
    {
        if (l_ < nr)
            return false;
        str.resize(nr);
        std::copy(s_, s_ + nr, str.data());
        forward_(nr);
        return true;
    }

    bool Strange::pop_raw(char *dst, size_t nr)
    {
        if (!dst)
            return false;
        if (l_ < nr)
            return false;
        std::memcpy(dst, s_, nr);
        forward_(nr);
        return true;
    }

    ix::Range Strange::ix_range() const
    {
        return ix::Range(s_ - b_, size());
    }

    Strange::Position Strange::position() const
    {
        Position pos;

        pos.ix = (s_ - b_);

        for (auto ptr = b_; ptr != s_; ++ptr)
            if (*ptr == '\n')
            {
                ++pos.line;
                pos.column = 0;
            }
            else
                ++pos.column;

        return pos;
    }

    // Privates
    bool Strange::invariants_() const
    {
        if (!s_ && l_)
            return false;
        return true;
    }
    void Strange::forward_(const size_t nr)
    {
        assert(nr <= l_);
        l_ -= nr;
        s_ += nr;
    }
    void Strange::shrink_(const size_t nr)
    {
        assert(nr <= l_);
        l_ -= nr;
    }

} // namespace rubr::parse

#ifndef HEADER_rubr_profile_Stopwatch_hpp_ALREADY_INCLUDED
#define HEADER_rubr_profile_Stopwatch_hpp_ALREADY_INCLUDED

#include <chrono>

namespace rubr::profile {

    class Stopwatch
    {
    public:
        void reset()
        {
            start_ = Clock::now();
        }

        template<typename Duration = std::chrono::nanoseconds>
        Duration elapse() const
        {
            return std::chrono::duration_cast<Duration>(Clock::now() - start_);
        }

    private:
        using Clock = std::chrono::high_resolution_clock;

        Clock::time_point start_ = Clock::now();
    };

} // namespace rubr::profile

#endif

#include <rubr/profile/Stopwatch.hpp>

#include <catch2/catch_test_macros.hpp>

#include <thread>

using namespace rubr;

TEST_CASE("elapse/reset tests", "[ut][profile][Stopwatch]")
{
    profile::Stopwatch sw;

    REQUIRE(sw.elapse() <= std::chrono::milliseconds(5));

    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    REQUIRE(sw.elapse() >= std::chrono::milliseconds(10));

    sw.reset();

    REQUIRE(sw.elapse() <= std::chrono::milliseconds(5));
}

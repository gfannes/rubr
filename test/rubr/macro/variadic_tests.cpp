#include <rubr/macro/variadic.h>

#include <catch2/catch_test_macros.hpp>

#define ONE(a) 1
#define TWO(a, b) 2
#define VARIADIC_MACRO(...) RUBR_GET_ARG_3((__VA_ARGS__, TWO, ONE))(__VA_ARGS__)

TEST_CASE("macro::variadic tests", "[ut]")
{
    SECTION("one")
    {
        const auto v = VARIADIC_MACRO(0);
        REQUIRE(v == 1);
    }
    SECTION("two")
    {
        const auto v = VARIADIC_MACRO(0, 0);
        REQUIRE(v == 2);
    }
}

#include <rubr/Version.hpp>

#include <catch2/catch_test_macros.hpp>

TEST_CASE("rubr.Version tests", "[ut][Version]")
{
    rubr::Version v{.major = 1, .minor = 2, .patch = 3};
    REQUIRE(v.to_str() == "1.2.3");
    REQUIRE(v.to_str("Version_") == "Version_1.2.3");
}

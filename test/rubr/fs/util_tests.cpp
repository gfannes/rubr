#include <rubr/fs/util.hpp>

#include <catch2/catch_test_macros.hpp>

using namespace rubr;

TEST_CASE("func", "[ut][fs][is_hidden]")
{
    {
        using T = std::filesystem::path;
        REQUIRE(fs::is_hidden(T(".abc")));
        REQUIRE(fs::is_hidden(T(".abc/")));

        REQUIRE(!fs::is_hidden(T(".abc/d")));
        REQUIRE(!fs::is_hidden(T("")));
    }
    {
        using T = std::string_view;
        REQUIRE(fs::is_hidden(T(".abc")));
        REQUIRE(fs::is_hidden(T(".abc/")));

        REQUIRE(!fs::is_hidden(T(".abc/d")));
        REQUIRE(!fs::is_hidden(T("")));
    }
}

TEST_CASE("func", "[ut][fs][read]")
{
    std::string content;
    REQUIRE(fs::read(content, "../../../../test/rubr/fs/util_tests.cpp"));
    REQUIRE(content.contains("rubr/fs/util.hpp"));
}

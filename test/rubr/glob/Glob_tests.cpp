#include <rubr/debug/log.hpp>
#include <rubr/glob/Glob.hpp>

#include <catch2/catch_test_macros.hpp>

#include <vector>

using namespace rubr;

TEST_CASE("", "[ut][glob][Glob]")
{
    struct Scn
    {
        glob::Glob::Config config;
    };
    Scn scn;

    struct Exp
    {
        std::vector<std::string> ok;
        std::vector<std::string> ko;
    };
    Exp exp;

    SECTION("empty")
    {
        scn.config.pattern = "";
        exp.ok.push_back("");
        exp.ko.push_back("abc");
        exp.ko.push_back("a/b/c");
    }
    SECTION("direct match")
    {
        scn.config.pattern = "abc";
        exp.ok.push_back("abc");
        exp.ko.push_back("abcd");
        exp.ko.push_back("_abcd");
    }
    SECTION("extension")
    {
        scn.config.pattern = "*.wav";
        SECTION("without path")
        {
            exp.ok.push_back("test.wav");
            exp.ko.push_back("dir/test.wav");
            exp.ko.push_back("test.wiv");
        }
        SECTION("with path")
        {
            scn.config.front = glob::Wildcard::All;
            exp.ok.push_back("test.wav");
            exp.ok.push_back("dir/test.wav");
            exp.ko.push_back("test.wiv");
        }
    }
    SECTION("nested")
    {
        scn.config.pattern = "**abc**";
        exp.ok.push_back("abc");
        exp.ok.push_back("_abc");
        exp.ok.push_back("abc_");
        exp.ok.push_back("_abc_");
        exp.ko.push_back("ab_c");
    }
    SECTION("second match")
    {
        scn.config.pattern = "**a*b";
        exp.ok.push_back("ab");
        exp.ok.push_back("acb");
        exp.ok.push_back("a/bacb");
        exp.ko.push_back("a/b");
    }

    glob::Glob glob{scn.config};

    S(nullptr);
    L(C(scn.config.pattern));
    for (const auto &str : exp.ok)
    {
        L("ok" C(str));
        REQUIRE(glob(str));
    }
    for (const auto &str : exp.ko)
    {
        L("ko" C(str));
        REQUIRE(!glob(str));
    }
}

TEST_CASE("func", "[ut][glob][Wildcard][max]")
{
    using W = glob::Wildcard;
    REQUIRE(glob::max(W::Nothing, W::Nothing) == W::Nothing);

    REQUIRE(glob::max(W::Nothing, W::Some) == W::Some);
    REQUIRE(glob::max(W::Some, W::Nothing) == W::Some);
    REQUIRE(glob::max(W::Some, W::Some) == W::Some);

    REQUIRE(glob::max(W::Nothing, W::All) == W::All);
    REQUIRE(glob::max(W::All, W::Nothing) == W::All);
    REQUIRE(glob::max(W::Some, W::All) == W::All);
    REQUIRE(glob::max(W::All, W::Some) == W::All);
    REQUIRE(glob::max(W::All, W::All) == W::All);
}

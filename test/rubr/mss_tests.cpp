#include <rubr/mss.hpp>

#include <catch2/catch_test_macros.hpp>

#include <string>

using namespace std;

namespace  { 
    enum class RC
    {
        OK, Error,
    };

    bool one(bool b)
    {
        MSS_BEGIN(bool);
        MSS(b);
        MSS_END();
    }
    bool two(bool b, string &msg)
    {
        MSS_BEGIN(bool);
        MSS(b, msg="fail");
        msg="ok";
        MSS_END();
    }
    bool three(bool b, string &msg)
    {
        MSS_BEGIN(bool);
        //Custom aggregator inverses the meaning of b
        MSS(b, msg="fail", [](bool &rc, bool b){rc = !b;});
        msg="ok";
        MSS_END();
    }
} 

TEST_CASE("MSS tests", "[ut][mss]")
{
    SECTION("one")
    {
        REQUIRE(one(true));
        REQUIRE(!one(false));
    }

    SECTION("two")
    {
        string msg;
        REQUIRE(two(true,msg));
        REQUIRE(msg=="ok");
        REQUIRE(!two(false,msg));
        REQUIRE(msg=="fail");
    }

    SECTION("three")
    {
        //Custom aggregator inverses the meaning of b
        string msg;
        REQUIRE(three(false,msg));
        REQUIRE(msg=="ok");
        REQUIRE(!three(true,msg));
        REQUIRE(msg=="fail");
    }
}

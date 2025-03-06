#include <rubr/cli/Range.hpp>

#include <catch2/catch_test_macros.hpp>

#include <vector>

using namespace rubr;

TEST_CASE("cli::Range tests", "[ut][cli][Range]")
{
    struct Scn
    {
        std::vector<const char *> args;
    };
    struct Exp
    {
        unsigned int size = 0;
        std::string exe_name;
        std::optional<std::string> input_opt;
        bool verbose_ok = true;
        int verbose = 0;
    };

    Scn scn;
    Exp exp;

    SECTION("default") {}
    SECTION("exe_name")
    {
        exp.exe_name = "exe_name";
        SECTION("exe_name -i input.txt -o output.txt")
        {
            scn.args = {"exe_name", "-i", "input.txt", "-v", "3"};
            exp.size = 5;
            exp.input_opt = "input.txt";
            exp.verbose = 3;
        }
        SECTION("verbose ko")
        {
            scn.args = {"exe_name", "-v", "abc"};
            exp.size = 3;
            exp.verbose_ok = false;
        }
    }

    {
        cli::Range argr{scn.args.size(), scn.args.data()};
        unsigned int size = 0;
        for (std::string str; argr.pop(str); ++size) {}
        REQUIRE(size == exp.size);
    }
    if (exp.size > 0)
    {
        cli::Range argr{scn.args.size(), scn.args.data()};

        std::string exe_name;
        REQUIRE(argr.pop(exe_name));
        REQUIRE(exe_name == exp.exe_name);

        for (std::string arg; argr.pop(arg);)
        {
            if (false) {}
            else if (arg == "-i")
            {
                std::optional<std::string> input_opt;
                REQUIRE(argr.pop(input_opt));
                REQUIRE(input_opt == exp.input_opt);
            }
            else if (arg == "-v")
            {
                int verbose;
                const auto verbose_ok = argr.pop(verbose);
                REQUIRE(verbose_ok == exp.verbose_ok);
                if (verbose_ok)
                    REQUIRE(verbose == exp.verbose);
            }
        }
    }
}

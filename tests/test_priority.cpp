#include "../catch.hpp"
#include <windows.h>

/* Declarations from nssm_testable.cpp */
int priority_constant_to_index(unsigned long constant);
unsigned long priority_index_to_constant(int index);

/* Priority index constants (from nssm.h) */
#define NSSM_REALTIME_PRIORITY       0
#define NSSM_HIGH_PRIORITY           1
#define NSSM_ABOVE_NORMAL_PRIORITY   2
#define NSSM_NORMAL_PRIORITY         3
#define NSSM_BELOW_NORMAL_PRIORITY   4
#define NSSM_IDLE_PRIORITY           5

TEST_CASE("priority_constant_to_index: REALTIME", "[priority]")
{
  REQUIRE(priority_constant_to_index(REALTIME_PRIORITY_CLASS) == NSSM_REALTIME_PRIORITY);
}

TEST_CASE("priority_constant_to_index: HIGH", "[priority]")
{
  REQUIRE(priority_constant_to_index(HIGH_PRIORITY_CLASS) == NSSM_HIGH_PRIORITY);
}

TEST_CASE("priority_constant_to_index: ABOVE_NORMAL", "[priority]")
{
  REQUIRE(priority_constant_to_index(ABOVE_NORMAL_PRIORITY_CLASS) == NSSM_ABOVE_NORMAL_PRIORITY);
}

TEST_CASE("priority_constant_to_index: NORMAL", "[priority]")
{
  REQUIRE(priority_constant_to_index(NORMAL_PRIORITY_CLASS) == NSSM_NORMAL_PRIORITY);
}

TEST_CASE("priority_constant_to_index: BELOW_NORMAL", "[priority]")
{
  REQUIRE(priority_constant_to_index(BELOW_NORMAL_PRIORITY_CLASS) == NSSM_BELOW_NORMAL_PRIORITY);
}

TEST_CASE("priority_constant_to_index: IDLE", "[priority]")
{
  REQUIRE(priority_constant_to_index(IDLE_PRIORITY_CLASS) == NSSM_IDLE_PRIORITY);
}

TEST_CASE("priority_constant_to_index: unknown value returns NORMAL", "[priority]")
{
  REQUIRE(priority_constant_to_index(0xDEAD) == NSSM_NORMAL_PRIORITY);
}

TEST_CASE("priority_constant_to_index: zero returns NORMAL", "[priority]")
{
  REQUIRE(priority_constant_to_index(0) == NSSM_NORMAL_PRIORITY);
}

TEST_CASE("priority_index_to_constant: REALTIME", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_REALTIME_PRIORITY) == REALTIME_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: HIGH", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_HIGH_PRIORITY) == HIGH_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: ABOVE_NORMAL", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_ABOVE_NORMAL_PRIORITY) == ABOVE_NORMAL_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: NORMAL", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_NORMAL_PRIORITY) == NORMAL_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: BELOW_NORMAL", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_BELOW_NORMAL_PRIORITY) == BELOW_NORMAL_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: IDLE", "[priority]")
{
  REQUIRE(priority_index_to_constant(NSSM_IDLE_PRIORITY) == IDLE_PRIORITY_CLASS);
}

TEST_CASE("priority_index_to_constant: out-of-range returns NORMAL", "[priority]")
{
  REQUIRE(priority_index_to_constant(99) == NORMAL_PRIORITY_CLASS);
  REQUIRE(priority_index_to_constant(-1) == NORMAL_PRIORITY_CLASS);
}

TEST_CASE("priority: roundtrip constant->index->constant", "[priority]")
{
  REQUIRE(priority_index_to_constant(priority_constant_to_index(REALTIME_PRIORITY_CLASS)) == REALTIME_PRIORITY_CLASS);
  REQUIRE(priority_index_to_constant(priority_constant_to_index(HIGH_PRIORITY_CLASS)) == HIGH_PRIORITY_CLASS);
  REQUIRE(priority_index_to_constant(priority_constant_to_index(NORMAL_PRIORITY_CLASS)) == NORMAL_PRIORITY_CLASS);
  REQUIRE(priority_index_to_constant(priority_constant_to_index(IDLE_PRIORITY_CLASS)) == IDLE_PRIORITY_CLASS);
}

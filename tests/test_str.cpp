#include "../catch.hpp"
#include <tchar.h>

/* Declarations from nssm_testable.cpp */
int str_equiv(const TCHAR* a, const TCHAR* b);
int str_number(const TCHAR* string, unsigned long* number);

TEST_CASE("str_equiv: identical strings return 1", "[str_equiv]")
{
  REQUIRE(str_equiv(_T("hello"), _T("hello")) == 1);
  REQUIRE(str_equiv(_T(""), _T("")) == 1);
  REQUIRE(str_equiv(_T("NSSM"), _T("NSSM")) == 1);
}

TEST_CASE("str_equiv: different case returns 1", "[str_equiv]")
{
  REQUIRE(str_equiv(_T("hello"), _T("HELLO")) == 1);
  REQUIRE(str_equiv(_T("NsSm"), _T("nSSm")) == 1);
  REQUIRE(str_equiv(_T("Install"), _T("INSTALL")) == 1);
}

TEST_CASE("str_equiv: different strings return 0", "[str_equiv]")
{
  REQUIRE(str_equiv(_T("hello"), _T("world")) == 0);
  REQUIRE(str_equiv(_T("abc"), _T("abd")) == 0);
}

TEST_CASE("str_equiv: different lengths return 0", "[str_equiv]")
{
  REQUIRE(str_equiv(_T("hello"), _T("helloworld")) == 0);
  REQUIRE(str_equiv(_T("long"), _T("lo")) == 0);
  REQUIRE(str_equiv(_T("a"), _T("ab")) == 0);
}

TEST_CASE("str_equiv: empty strings return 1", "[str_equiv]")
{
  REQUIRE(str_equiv(_T(""), _T("")) == 1);
}

TEST_CASE("str_number: valid number string", "[str_number]")
{
  unsigned long num = 0;
  REQUIRE(str_number(_T("123"), &num) == 0);
  REQUIRE(num == 123);

  REQUIRE(str_number(_T("0"), &num) == 0);
  REQUIRE(num == 0);

  REQUIRE(str_number(_T("4294967295"), &num) == 0);
  REQUIRE(num == 4294967295UL);
}

TEST_CASE("str_number: NULL string returns 1", "[str_number]")
{
  unsigned long num = 0;
  REQUIRE(str_number(NULL, &num) == 1);
}

TEST_CASE("str_number: non-numeric string returns 2", "[str_number]")
{
  unsigned long num = 0;
  REQUIRE(str_number(_T("abc"), &num) == 2);
  REQUIRE(str_number(_T("12abc"), &num) == 2);
}

TEST_CASE("str_number: hex and octal strings", "[str_number]")
{
  unsigned long num = 0;
  REQUIRE(str_number(_T("0xFF"), &num) == 0);
  REQUIRE(num == 255);

  REQUIRE(str_number(_T("010"), &num) == 0);
  REQUIRE(num == 8);
}

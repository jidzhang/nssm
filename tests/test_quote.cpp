#include "../catch.hpp"
#include <tchar.h>
#include <string.h>

/* Declaration from nssm_testable.cpp */
int quote(const TCHAR* unquoted, TCHAR* buffer, size_t buflen);

TEST_CASE("quote: string without special chars is unchanged", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("hello"), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("hello")) == 0);
}

TEST_CASE("quote: string without special chars (path)", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("C:\\foo\\bar.exe"), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("C:\\foo\\bar.exe")) == 0);
}

TEST_CASE("quote: string with space gets quoted", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("hello world"), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("\"hello world\"")) == 0);
}

TEST_CASE("quote: string with tab gets quoted", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("hello\tworld"), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("\"hello\tworld\"")) == 0);
}

TEST_CASE("quote: empty string is unchanged", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T(""), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("")) == 0);
}

TEST_CASE("quote: buffer too small returns 1", "[quote]")
{
  TCHAR buf[4];
  /* "hello" is 5 chars, buflen=4 is not enough */
  REQUIRE(quote(_T("hello"), buf, _countof(buf)) == 1);
}

TEST_CASE("quote: buffer too small for quoted string", "[quote]")
{
  TCHAR buf[8];
  /* "hello world" needs to become "hello world" (12 chars + null = 13) */
  REQUIRE(quote(_T("hello world"), buf, _countof(buf)) == 1);
}

TEST_CASE("quote: string with ampersand gets escaped", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("foo&bar"), buf, _countof(buf)) == 0);
  /* Should be quoted and escaped: ^"foo^&bar^" */
  REQUIRE(_tcscmp(buf, _T("^\"foo^&bar^\"")) == 0);
}

TEST_CASE("quote: string with pipe gets escaped", "[quote]")
{
  TCHAR buf[256];
  REQUIRE(quote(_T("a|b"), buf, _countof(buf)) == 0);
  REQUIRE(_tcscmp(buf, _T("^\"a^|b^\"")) == 0);
}

TEST_CASE("quote: string with embedded quotes", "[quote]")
{
  TCHAR buf[256];
  /* Input: he"llo (contains a quote character) */
  TCHAR input[] = { 'h', 'e', '"', 'l', 'l', 'o', '\0' };
  REQUIRE(quote(input, buf, _countof(buf)) == 0);
  /* " triggers escape mode.
     Expected: ^"he^\^"llo^"
     Characters: ^ " h e ^ \ ^ " l l o ^ " */
  TCHAR expected[] = { '^', '"', 'h', 'e', '^', '\\', '^', '"', 'l', 'l', 'o', '^', '"', '\0' };
  REQUIRE(_tcscmp(buf, expected) == 0);
}

TEST_CASE("quote: exact buffer size fits", "[quote]")
{
  /* "hi" is 2 chars + null = 3, buflen=3 should succeed */
  TCHAR buf[3];
  REQUIRE(quote(_T("hi"), buf, 3) == 0);
  REQUIRE(_tcscmp(buf, _T("hi")) == 0);
}

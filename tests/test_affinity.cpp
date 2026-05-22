#include "../catch.hpp"
#include <windows.h>
#include <tchar.h>
#include <string.h>

/* Declarations from nssm_testable.cpp */
int affinity_string_to_mask(TCHAR* string, __int64* mask);
int affinity_mask_to_string(__int64 mask, TCHAR** string);

TEST_CASE("affinity_string_to_mask: single CPU 0", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("0"), &mask) == 0);
  REQUIRE(mask == 1);
}

TEST_CASE("affinity_string_to_mask: single CPU 1", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("1"), &mask) == 0);
  REQUIRE(mask == 2);
}

TEST_CASE("affinity_string_to_mask: comma separated 0,2", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("0,2"), &mask) == 0);
  REQUIRE(mask == 5);
}

TEST_CASE("affinity_string_to_mask: range 0-3", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("0-3"), &mask) == 0);
  REQUIRE(mask == 15);
}

TEST_CASE("affinity_string_to_mask: range 2-5", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("2-5"), &mask) == 0);
  /* bits 2,3,4,5 = 0x3C = 60 */
  REQUIRE(mask == 60);
}

TEST_CASE("affinity_string_to_mask: NULL string gives mask 0", "[affinity]")
{
  __int64 mask = 99;
  REQUIRE(affinity_string_to_mask(NULL, &mask) == 0);
  REQUIRE(mask == 0);
}

TEST_CASE("affinity_string_to_mask: NULL mask returns 1", "[affinity]")
{
  REQUIRE(affinity_string_to_mask(_T("0"), NULL) == 1);
}

TEST_CASE("affinity_string_to_mask: mixed range and comma", "[affinity]")
{
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask(_T("0-1,3"), &mask) == 0);
  /* bits 0,1,3 = 0x0B = 11 */
  REQUIRE(mask == 11);
}

TEST_CASE("affinity_mask_to_string: mask 1 -> 0", "[affinity]")
{
  TCHAR* str = NULL;
  REQUIRE(affinity_mask_to_string(1, &str) == 0);
  REQUIRE(str != NULL);
  REQUIRE(_tcscmp(str, _T("0")) == 0);
  HeapFree(GetProcessHeap(), 0, str);
}

TEST_CASE("affinity_mask_to_string: mask 5 -> 0,2", "[affinity]")
{
  TCHAR* str = NULL;
  REQUIRE(affinity_mask_to_string(5, &str) == 0);
  REQUIRE(str != NULL);
  REQUIRE(_tcscmp(str, _T("0,2")) == 0);
  HeapFree(GetProcessHeap(), 0, str);
}

TEST_CASE("affinity_mask_to_string: mask 15 -> 0-3", "[affinity]")
{
  TCHAR* str = NULL;
  REQUIRE(affinity_mask_to_string(15, &str) == 0);
  REQUIRE(str != NULL);
  REQUIRE(_tcscmp(str, _T("0-3")) == 0);
  HeapFree(GetProcessHeap(), 0, str);
}

TEST_CASE("affinity_mask_to_string: mask 3 -> 0,1", "[affinity]")
{
  TCHAR* str = NULL;
  /* bits 0 and 1 are adjacent. When last==first+1, code uses ',' not '-' */
  REQUIRE(affinity_mask_to_string(3, &str) == 0);
  REQUIRE(str != NULL);
  REQUIRE(_tcscmp(str, _T("0,1")) == 0);
  HeapFree(GetProcessHeap(), 0, str);
}

TEST_CASE("affinity_mask_to_string: mask 0 returns 0 with null string", "[affinity]")
{
  TCHAR* str = (TCHAR*)1;
  REQUIRE(affinity_mask_to_string(0, &str) == 0);
  REQUIRE(str == NULL);
}

TEST_CASE("affinity_mask_to_string: NULL string pointer returns 1", "[affinity]")
{
  REQUIRE(affinity_mask_to_string(1, NULL) == 1);
}

TEST_CASE("affinity: roundtrip string->mask->string", "[affinity]")
{
  const TCHAR* input = _T("0-3");
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask((TCHAR*)input, &mask) == 0);
  REQUIRE(mask == 15);

  TCHAR* output = NULL;
  REQUIRE(affinity_mask_to_string(mask, &output) == 0);
  REQUIRE(output != NULL);
  REQUIRE(_tcscmp(output, _T("0-3")) == 0);
  HeapFree(GetProcessHeap(), 0, output);
}

TEST_CASE("affinity: roundtrip with comma separated", "[affinity]")
{
  const TCHAR* input = _T("0,2,4");
  __int64 mask = 0;
  REQUIRE(affinity_string_to_mask((TCHAR*)input, &mask) == 0);
  /* bits 0,2,4 = 0x15 = 21 */
  REQUIRE(mask == 21);

  TCHAR* output = NULL;
  REQUIRE(affinity_mask_to_string(mask, &output) == 0);
  REQUIRE(output != NULL);
  REQUIRE(_tcscmp(output, _T("0,2,4")) == 0);
  HeapFree(GetProcessHeap(), 0, output);
}

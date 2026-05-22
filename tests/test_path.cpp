#include "../catch.hpp"
#include <tchar.h>
#include <string.h>

/* Declaration from nssm_testable.cpp */
void strip_basename(TCHAR* buffer);

TEST_CASE("strip_basename: removes filename from full path", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("C:\\foo\\bar.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("C:\\foo")) == 0);
}

TEST_CASE("strip_basename: drive root keeps backslash", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("C:\\foo"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("C:\\")) == 0);
}

TEST_CASE("strip_basename: no directory part yields empty", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("bar.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("")) == 0);
}

TEST_CASE("strip_basename: deep nested path", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("C:\\foo\\bar\\baz.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("C:\\foo\\bar")) == 0);
}

TEST_CASE("strip_basename: single backslash yields empty", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("\\bar.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("")) == 0);
}

TEST_CASE("strip_basename: UNC path", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("\\\\server\\share\\file.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("\\\\server\\share")) == 0);
}

TEST_CASE("strip_basename: forward slashes", "[strip_basename]")
{
  TCHAR buf[256];
  _tcscpy_s(buf, _countof(buf), _T("C:/foo/bar.exe"));
  strip_basename(buf);
  REQUIRE(_tcscmp(buf, _T("C:/foo")) == 0);
}

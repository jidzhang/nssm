#ifndef NSSM_UTIL_H
#define NSSM_UTIL_H

/*
  Pure utility functions extracted from nssm.cpp and service.cpp
  for testability and deduplication with tests/nssm_testable.cpp.
*/

#include <windows.h>
#include <tchar.h>

/* String utilities (from nssm.cpp) */
int str_equiv(const TCHAR* a, const TCHAR* b);
int str_number(const TCHAR* string, unsigned long* number, TCHAR** bogus);
int str_number(const TCHAR* string, unsigned long* number);
int quote(const TCHAR* unquoted, TCHAR* buffer, size_t buflen);
void strip_basename(TCHAR* buffer);

/* Priority utilities (from service.cpp) */
unsigned long priority_mask();
int priority_constant_to_index(unsigned long constant);
unsigned long priority_index_to_constant(int index);

/* Affinity utilities (from service.cpp) */
int affinity_mask_to_string(__int64 mask, TCHAR** string);
int affinity_string_to_mask(TCHAR* string, __int64* mask);

#endif

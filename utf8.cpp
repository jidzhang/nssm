#include "nssm.h"

static unsigned long cp;

void setup_utf8()
{
#ifdef UNICODE
	/*
	  Ensure we write in UTF-8 mode, so that non-ASCII characters don't get
	  mangled.  If we were compiled in ANSI mode it won't work.
	 */
	cp = GetConsoleOutputCP();
	SetConsoleOutputCP(CP_UTF8);
	_setmode(_fileno(stdout), _O_U8TEXT);
	_setmode(_fileno(stderr), _O_U8TEXT);
#endif
}

void unsetup_utf8()
{
	if (cp) SetConsoleOutputCP(cp);
}

/*
  Conversion functions.

  to_utf8/16() converts a string which may be either utf8 or utf16 to
  the desired format.  If no conversion is needed a new string is still
  allocated and the old string is copied.

  from_utf8/16() converts a string which IS in the specified format to
  whichever format is needed according to whether UNICODE is defined.
  It simply wraps the appropriate to_utf8/16() function.

  Therefore the caller must ALWAYS free the destination pointer after a
  successful (return code 0) call to one of these functions.

  The length pointer is optional.  Pass NULL if you don't care about
  the length of the converted string.

  Both the destination and the length, if supplied, will be zeroed if
  no conversion was done.
*/
int to_utf8(const wchar_t* utf16, char** utf8, unsigned long* utf8len)
{
	*utf8 = 0;
	if (utf8len) *utf8len = 0;
	int size = WideCharToMultiByte(CP_UTF8, 0, utf16, -1, NULL, 0, NULL, NULL);
	if (!size) return 1;

	ScopedHeapBuffer<char> buf(size);
	if (!buf) return 2;

	if (!WideCharToMultiByte(CP_UTF8, 0, utf16, -1, buf, size, NULL, NULL))
		return 3;

	*utf8 = buf.detach();
	if (utf8len) *utf8len = (unsigned long)strlen(*utf8);

	return 0;
}

int to_utf8(const char* ansi, char** utf8, unsigned long* utf8len)
{
	*utf8 = 0;
	if (utf8len) *utf8len = 0;
	size_t len = strlen(ansi);
	int size = (int)len + 1;

	ScopedHeapBuffer<char> buf(size);
	if (!buf) return 2;

	if (utf8len) *utf8len = (unsigned long)len;
	memmove(buf, ansi, size);

	*utf8 = buf.detach();
	return 0;
}

int to_utf16(const char* utf8, wchar_t** utf16, unsigned long* utf16len)
{
	*utf16 = 0;
	if (utf16len) *utf16len = 0;
	int size = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
	if (!size) return 1;

	ScopedHeapBuffer<wchar_t> buf(size);
	if (!buf) return 2;

	if (!MultiByteToWideChar(CP_UTF8, 0, utf8, -1, buf, size))
		return 3;

	*utf16 = buf.detach();
	if (utf16len) *utf16len = (unsigned long)wcslen(*utf16);

	return 0;
}

int to_utf16(const wchar_t* unicode, wchar_t** utf16, unsigned long* utf16len)
{
	*utf16 = 0;
	if (utf16len) *utf16len = 0;
	size_t len = wcslen(unicode);
	int byte_size = ((int)len + 1) * sizeof(wchar_t);

	ScopedHeapBuffer<wchar_t> buf(len + 1);
	if (!buf) return 2;

	if (utf16len) *utf16len = (unsigned long)len;
	memmove(buf, unicode, byte_size);

	*utf16 = buf.detach();
	return 0;
}

int from_utf8(const char* utf8, TCHAR** buffer, unsigned long* buflen)
{
#ifdef UNICODE
	return to_utf16(utf8, buffer, buflen);
#else
	return to_utf8(utf8, buffer, buflen);
#endif
}

int from_utf16(const wchar_t* utf16, TCHAR** buffer, unsigned long* buflen)
{
#ifdef UNICODE
	return to_utf16(utf16, buffer, buflen);
#else
	return to_utf8(utf16, buffer, buflen);
#endif
}
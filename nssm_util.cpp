#include "nssm_util.h"

/* Priority index constants (also in nssm.h) */
#ifndef NSSM_REALTIME_PRIORITY
#define NSSM_REALTIME_PRIORITY       0
#define NSSM_HIGH_PRIORITY           1
#define NSSM_ABOVE_NORMAL_PRIORITY   2
#define NSSM_NORMAL_PRIORITY         3
#define NSSM_BELOW_NORMAL_PRIORITY   4
#define NSSM_IDLE_PRIORITY           5
#endif

typedef struct
{
	int first;
	int last;
} list_t;

/* Are two strings case-insensitively equivalent? */
int str_equiv(const TCHAR* a, const TCHAR* b)
{
	size_t len = _tcslen(a);
	if (_tcslen(b) != len) return 0;
	if (_tcsnicmp(a, b, len)) return 0;
	return 1;
}

/* Convert a string to a number. */
int str_number(const TCHAR* string, unsigned long* number, TCHAR** bogus)
{
	if (!string) return 1;

	*number = _tcstoul(string, bogus, 0);
	if (**bogus) return 2;

	return 0;
}

int str_number(const TCHAR* string, unsigned long* number)
{
	TCHAR* bogus;
	return str_number(string, number, &bogus);
}

/* Does a char need to be escaped? */
static bool needs_escape(const TCHAR c)
{
	if (c == _T('"')) return true;
	if (c == _T('&')) return true;
	if (c == _T('%')) return true;
	if (c == _T('^')) return true;
	if (c == _T('<')) return true;
	if (c == _T('>')) return true;
	if (c == _T('|')) return true;
	return false;
}

/* Does a char need to be quoted? */
static bool needs_quote(const TCHAR c)
{
	if (c == _T(' ')) return true;
	if (c == _T('\t')) return true;
	if (c == _T('\n')) return true;
	if (c == _T('\v')) return true;
	if (c == _T('"')) return true;
	if (c == _T('*')) return true;
	return needs_escape(c);
}

/* https://blogs.msdn.microsoft.com/twistylittlepassagesallalike/2011/04/23/everyone-quotes-command-line-arguments-the-wrong-way/ */
/* http://www.robvanderwoude.com/escapechars.php */
int quote(const TCHAR* unquoted, TCHAR* buffer, size_t buflen)
{
	size_t i, j, n;
	size_t len = _tcslen(unquoted);
	if (len > buflen - 1) return 1;

	bool escape = false;
	bool quotes = false;

	for (i = 0; i < len; i++)
	{
		if (needs_escape(unquoted[i]))
		{
			escape = quotes = true;
			break;
		}
		if (needs_quote(unquoted[i])) quotes = true;
	}
	if (!quotes)
	{
		memmove(buffer, unquoted, (len + 1) * sizeof(TCHAR));
		return 0;
	}

	/* "" */
	size_t quoted_len = 2;
	if (escape) quoted_len += 2;
	for (i = 0; ; i++)
	{
		n = 0;

		while (i != len && unquoted[i] == _T('\\'))
		{
			i++;
			n++;
		}

		if (i == len)
		{
			quoted_len += n * 2;
			break;
		}
		else if (unquoted[i] == _T('"')) quoted_len += n * 2 + 2;
		else quoted_len += n + 1;
		if (needs_escape(unquoted[i])) quoted_len += n;
	}
	if (quoted_len > buflen - 1) return 1;

	TCHAR* s = buffer;
	if (escape) *s++ = _T('^');
	*s++ = _T('"');

	for (i = 0; ; i++)
	{
		n = 0;

		while (i != len && unquoted[i] == _T('\\'))
		{
			i++;
			n++;
		}

		if (i == len)
		{
			for (j = 0; j < n * 2; j++)
			{
				if (escape) *s++ = _T('^');
				*s++ = _T('\\');
			}
			break;
		}
		else if (unquoted[i] == _T('"'))
		{
			for (j = 0; j < n * 2 + 1; j++)
			{
				if (escape) *s++ = _T('^');
				*s++ = _T('\\');
			}
			if (escape && needs_escape(unquoted[i])) *s++ = _T('^');
			*s++ = unquoted[i];
		}
		else
		{
			for (j = 0; j < n; j++)
			{
				if (escape) *s++ = _T('^');
				*s++ = _T('\\');
			}
			if (escape && needs_escape(unquoted[i])) *s++ = _T('^');
			*s++ = unquoted[i];
		}
	}
	if (escape) *s++ = _T('^');
	*s++ = _T('"');
	*s++ = _T('\0');

	return 0;
}

/* Remove basename of a path. */
void strip_basename(TCHAR* buffer)
{
	size_t len = _tcslen(buffer);
	size_t i;
	for (i = len; i && buffer[i] != _T('\\') && buffer[i] != _T('/'); i--);
	/* X:\ is OK. */
	if (i && buffer[i - 1] == _T(':')) i++;
	buffer[i] = _T('\0');
}

unsigned long priority_mask()
{
	return REALTIME_PRIORITY_CLASS | HIGH_PRIORITY_CLASS | ABOVE_NORMAL_PRIORITY_CLASS | NORMAL_PRIORITY_CLASS | BELOW_NORMAL_PRIORITY_CLASS | IDLE_PRIORITY_CLASS;
}

int priority_constant_to_index(unsigned long constant)
{
	switch (constant & priority_mask())
	{
	case REALTIME_PRIORITY_CLASS: return NSSM_REALTIME_PRIORITY;
	case HIGH_PRIORITY_CLASS: return NSSM_HIGH_PRIORITY;
	case ABOVE_NORMAL_PRIORITY_CLASS: return NSSM_ABOVE_NORMAL_PRIORITY;
	case BELOW_NORMAL_PRIORITY_CLASS: return NSSM_BELOW_NORMAL_PRIORITY;
	case IDLE_PRIORITY_CLASS: return NSSM_IDLE_PRIORITY;
	}
	return NSSM_NORMAL_PRIORITY;
}

unsigned long priority_index_to_constant(int index)
{
	switch (index)
	{
	case NSSM_REALTIME_PRIORITY: return REALTIME_PRIORITY_CLASS;
	case NSSM_HIGH_PRIORITY: return HIGH_PRIORITY_CLASS;
	case NSSM_ABOVE_NORMAL_PRIORITY: return ABOVE_NORMAL_PRIORITY_CLASS;
	case NSSM_BELOW_NORMAL_PRIORITY: return BELOW_NORMAL_PRIORITY_CLASS;
	case NSSM_IDLE_PRIORITY: return IDLE_PRIORITY_CLASS;
	}
	return NORMAL_PRIORITY_CLASS;
}

int affinity_mask_to_string(__int64 mask, TCHAR** string)
{
	if (!string) return 1;
	if (!mask)
	{
		*string = 0;
		return 0;
	}

	__int64 i, n;

	/* SetProcessAffinityMask() accepts a mask of up to 64 processors. */
	list_t set[64];
	for (n = 0; n < _countof(set); n++) set[n].first = set[n].last = -1;

	for (i = 0, n = 0; i < _countof(set); i++)
	{
		if (mask & (1LL << i))
		{
			if (set[n].first == -1) set[n].first = set[n].last = (int)i;
			else if (set[n].last == (int)i - 1) set[n].last = (int)i;
			else
			{
				n++;
				set[n].first = set[n].last = (int)i;
			}
		}
	}

	/* Worst case is 2x2 characters for first and last CPU plus - and/or , */
	size_t len = (size_t)(n + 1) * 6;
	*string = (TCHAR*)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, len * sizeof(TCHAR));
	if (!*string) return 2;

	size_t s = 0;
	int ret;
	for (i = 0; i <= n; i++)
	{
		if (i) (*string)[s++] = _T(',');
		ret = _sntprintf_s(*string + s, 3, _TRUNCATE, _T("%u"), set[i].first);
		if (ret < 0)
		{
			HeapFree(GetProcessHeap(), 0, *string);
			*string = 0;
			return 3;
		}
		else s += ret;
		if (set[i].last != set[i].first)
		{
			ret = _sntprintf_s(*string + s, 4, _TRUNCATE, _T("%c%u"), (set[i].last == set[i].first + 1) ? _T(',') : _T('-'), set[i].last);
			if (ret < 0)
			{
				HeapFree(GetProcessHeap(), 0, *string);
				*string = 0;
				return 4;
			}
			else s += ret;
		}
	}

	return 0;
}

int affinity_string_to_mask(TCHAR* string, __int64* mask)
{
	if (!mask) return 1;

	*mask = 0LL;
	if (!string) return 0;

	list_t set[64];

	TCHAR* s = string;
	TCHAR* end;
	int ret;
	int i;
	int n = 0;
	unsigned long number;

	for (n = 0; n < _countof(set); n++) set[n].first = set[n].last = -1;
	n = 0;

	while (*s)
	{
		ret = str_number(s, &number, &end);
		s = end;
		if (ret == 0 || ret == 2)
		{
			if (number >= _countof(set)) return 2;
			set[n].first = set[n].last = (int)number;

			switch (*s)
			{
			case 0:
				break;

			case _T(','):
				n++;
				s++;
				break;

			case _T('-'):
				if (!*(++s)) return 3;
				ret = str_number(s, &number, &end);
				if (ret == 0 || ret == 2)
				{
					s = end;
					if (!*s || *s == _T(','))
					{
						set[n].last = (int)number;
						if (!*s) break;
						n++;
						s++;
					}
					else return 3;
				}
				else return 3;
				break;

			default:
				return 3;
			}
		}
		else return 4;
	}

	for (i = 0; i <= n; i++)
	{
		for (int j = set[i].first; j <= set[i].last; j++) (__int64)* mask |= (1LL << (__int64)j);
	}

	return 0;
}

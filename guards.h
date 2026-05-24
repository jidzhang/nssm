#ifndef GUARDS_H
#define GUARDS_H

/*
  RAII guard classes for Win32 handle types.
  Each guard owns one handle and closes it in the destructor.
  No inheritance, no virtual methods, no heap allocation.
  C++03 compatible.
*/

/* Guard for HANDLE (CloseHandle). */
class HandleGuard {
public:
	explicit HandleGuard(HANDLE h = INVALID_HANDLE_VALUE) : handle_(h) {}
	~HandleGuard() { close(); }

	HANDLE get() const { return handle_; }

	/* Returns the handle and releases ownership. */
	HANDLE detach() {
		HANDLE h = handle_;
		handle_ = INVALID_HANDLE_VALUE;
		return h;
	}

	/* Closes the current handle and takes ownership of a new one. */
	void reset(HANDLE h) {
		close();
		handle_ = h;
	}

	/* Closes the handle if it is valid. */
	void close() {
		if (handle_ && handle_ != INVALID_HANDLE_VALUE)
		{
			CloseHandle(handle_);
			handle_ = INVALID_HANDLE_VALUE;
		}
	}

	/* Safe-bool: true if the guard holds a valid handle. */
	operator bool() const {
		return handle_ && handle_ != INVALID_HANDLE_VALUE;
	}
	bool operator!() const {
		return !static_cast<bool>(*this);
	}

	/* Implicit conversion for Win32 API calls. */
	operator HANDLE() const { return handle_; }

private:
	HANDLE handle_;
	/* Non-copyable. */
	HandleGuard(const HandleGuard&);
	HandleGuard& operator=(const HandleGuard&);
};

/* Guard for HKEY (RegCloseKey). */
class RegistryKeyGuard {
public:
	explicit RegistryKeyGuard(HKEY key = NULL) : key_(key) {}
	~RegistryKeyGuard() { close(); }

	HKEY get() const { return key_; }

	HKEY detach() {
		HKEY k = key_;
		key_ = NULL;
		return k;
	}

	void reset(HKEY key) {
		close();
		key_ = key;
	}

	void close() {
		if (key_)
		{
			RegCloseKey(key_);
			key_ = NULL;
		}
	}

	operator bool() const { return key_ != NULL; }
	bool operator!() const { return key_ == NULL; }
	operator HKEY() const { return key_; }

private:
	HKEY key_;
	RegistryKeyGuard(const RegistryKeyGuard&);
	RegistryKeyGuard& operator=(const RegistryKeyGuard&);
};

/* Guard for SC_HANDLE (CloseServiceHandle). */
class ScHandleGuard {
public:
	explicit ScHandleGuard(SC_HANDLE h = NULL) : handle_(h) {}
	~ScHandleGuard() { close(); }

	SC_HANDLE get() const { return handle_; }

	SC_HANDLE detach() {
		SC_HANDLE h = handle_;
		handle_ = NULL;
		return h;
	}

	void reset(SC_HANDLE h) {
		close();
		handle_ = h;
	}

	void close() {
		if (handle_)
		{
			CloseServiceHandle(handle_);
			handle_ = NULL;
		}
	}

	operator bool() const { return handle_ != NULL; }
	bool operator!() const { return handle_ == NULL; }
	operator SC_HANDLE() const { return handle_; }

private:
	SC_HANDLE handle_;
	ScHandleGuard(const ScHandleGuard&);
	ScHandleGuard& operator=(const ScHandleGuard&);
};

#endif

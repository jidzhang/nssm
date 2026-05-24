#ifndef HEAP_PTR_H
#define HEAP_PTR_H

/*
  Heap memory management policies for the smart_ptr library,
  and a scoped heap buffer class for temporary allocations.

  heap_mem_mgr<T>  - for shared_ptr to manage HeapAlloc'd objects
  heap_array_mgr<T> - for shared_array to manage HeapAlloc'd buffers
  ScopedHeapBuffer<T> - RAII wrapper for local HeapAlloc'd buffers
*/

#include <windows.h>
#include <string>

/* Securely clear a wstring's contents from memory before deallocation. */
inline void secure_clear(std::wstring& s) {
	if (!s.empty())
	{
		SecureZeroMemory(&s[0], s.size() * sizeof(wchar_t));
	}
	s.clear();
}

/* Memory manager policy that uses HeapAlloc/HeapFree. */
namespace smart_ptr {
	template <typename T>
	class heap_mem_mgr {
	public:
		static void deallocate(T* p) {
			if (p) HeapFree(GetProcessHeap(), 0, p);
		}
		static T* allocate() {
			return static_cast<T*>(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(T)));
		}
	};

	template <typename T>
	class heap_array_mgr {
	public:
		static void deallocate(T* p) {
			if (p) HeapFree(GetProcessHeap(), 0, p);
		}
	};
} // namespace smart_ptr

/*
  ScopedHeapBuffer: non-copyable RAII wrapper for a HeapAlloc'd buffer.
  Use for the common pattern of local TCHAR* buf = HeapAlloc(...);
  The destructor calls HeapFree automatically.
*/
template <typename T>
class ScopedHeapBuffer {
public:
	ScopedHeapBuffer() : ptr_(NULL) {}

	explicit ScopedHeapBuffer(size_t count) {
		ptr_ = static_cast<T*>(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, count * sizeof(T)));
	}

	~ScopedHeapBuffer() {
		if (ptr_) HeapFree(GetProcessHeap(), 0, ptr_);
	}

	/* Allocate (or reallocate) the buffer. Returns false on failure. */
	bool alloc(size_t count) {
		if (ptr_)
		{
			HeapFree(GetProcessHeap(), 0, ptr_);
			ptr_ = NULL;
		}
		ptr_ = static_cast<T*>(HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, count * sizeof(T)));
		return ptr_ != NULL;
	}

	T* get() const { return ptr_; }
	T& operator[](size_t i) { return ptr_[i]; }
	const T& operator[](size_t i) const { return ptr_[i]; }
	T& operator[](int i) { return ptr_[i]; }
	const T& operator[](int i) const { return ptr_[i]; }

	operator T* () const { return ptr_; }
	operator bool() const { return ptr_ != NULL; }
	bool operator!() const { return ptr_ == NULL; }

	/* Release ownership without freeing. */
	T* detach() {
		T* p = ptr_;
		ptr_ = NULL;
		return p;
	}

private:
	T* ptr_;
	ScopedHeapBuffer(const ScopedHeapBuffer&);
	ScopedHeapBuffer& operator=(const ScopedHeapBuffer&);
};

#endif

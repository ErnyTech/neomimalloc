// Written in the D programming language.
/**
This module provides high-level interface for mi-mallocator
Copyright: Copyright 2019 Ernesto Castellotti <erny.castell@gmail.com>
License:   $(HTTP https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License - Version 2.0).
Authors:   $(HTTP github.com/ErnyTech, Ernesto Castellotti)
*/
module neomimalloc.mimallocator;

/**
 * High-level interface for mimalloc.
 */
struct Mimallocator {
    import std.experimental.allocator.common : platformAlignment;
    import std.typecons : Ternary;

    /**
     * Returns the global instance of this allocator type.
     * Mimallocator is thread-safe, all methods are shared.
     */
    static shared Mimallocator instance;

    /**
     * The alignment is a static constant equal to `platformAlignment`, which
     * ensures proper alignment for any D data type.
     */    
    enum uint alignment = platformAlignment;

    /**
     * Return the memory size that will be allocated asking for the minimum required size.
     *
     * Params:
     *      size = The minimal required size in bytes.
     *
     * Returns:
     *      the size n that will be allocated, where n >= size.
     */
    @trusted @nogc nothrow size_t goodAllocSize(size_t size) shared {
        import neomimalloc.c.mimalloc : mi_good_size;

        return mi_good_size(size);
    }

    /**
     * Allocates the size expressed in bytes.
     *
     * Params:
     *      bytes = Number of bytes to allocate.
     *
     * Returns:
     *      An array with allocated memory or null if out of memory. Returns null if called with size 0.
     */
    @trusted @nogc pure nothrow void[] allocate(size_t bytes) shared {
        import neomimalloc.c.mimalloc : mi_malloc;

        if (bytes == 0) {
            return null;
        }

        auto p = mi_malloc(bytes);
        return p ? p[0 .. bytes] : null;
    }

    /**
     * Allocates the size expressed in bytes aligned by alignment.
     *
     * Params:
     *      bytes = Number of bytes to allocate.
     *      alignment = the minimal alignment of the allocated memory.
     *
     * Returns:
     *      An array with aligned allocated memory or null if out of memory. Returns null if called with size 0.
     */
    @trusted @nogc pure nothrow void[] alignedAllocate(size_t bytes, uint alignment) shared {
        import neomimalloc.c.mimalloc : mi_malloc_aligned;

        if (bytes == 0) {
            return null;
        }

        auto p = mi_malloc_aligned(bytes, alignment);
        return p ? p[0 .. bytes] : null;
    }

    /**
     * Expands the array by increasing its length with the required delta.
     *
     * Params:
     *      b = The array to be expanded (old size + delta).
     *      delta = The dimension to be increased.
     *
     * Returns:
     *   true if the expansion was successful, false if the array is null or the allocator has failed.  
     */
    @system @nogc pure nothrow bool expand(ref void[] b, size_t delta) shared {
        import neomimalloc.c.mimalloc : mi_expand;

        if (delta == 0) {
            return true;
        }

        if (b is null) {
            return false;
        }

        auto newSize = b.length + delta;
        auto p = cast(ubyte*) mi_expand(b.ptr, newSize);

        if (!p) {
            return false;
        }
        
        b = p[0 .. newSize];
        return true;
    }

    /**
     * Re-allocate memory to newsize bytes.
     *
     * Params:
     *      b = The array to be reallocated.
     *      newSize = The new size that the array will take.
     *
     * Returns:
     *   true if the reallocatiom was successful, false if the allocator has failed. 
     */
    @system @nogc pure nothrow bool reallocate(ref void[] b, size_t newSize) shared {
        import neomimalloc.c.mimalloc : mi_realloc;

        auto p = cast(ubyte*) mi_realloc(b.ptr, newSize);

        if (!p) {
            return false;
        }

        b = p[0 .. newSize];
        return true;
    }

    /**
     * Re-allocate memory to newsize bytes aligned by alignment.
     *
     * Params:
     *      b = The array to be reallocated.
     *      newSize = The new size that the array will take.
     *      alignment = The minimal alignment of the allocated memory.
     *
     * Returns:
     *   true if the reallocatiom was successful, false if the allocator has failed   
     */
    @system @nogc pure nothrow bool alignedReallocate(ref void[] b, size_t newSize, uint alignment) shared {
        import neomimalloc.c.mimalloc : mi_realloc_aligned;

        auto p = cast(ubyte*) mi_realloc_aligned(b.ptr, newSize, alignment);

        if (!p) {
            return false;
        }

        b = p[0 .. newSize];
        return true;
    }

    /**
     * Checks if the memory has been allocated by this allocator.
     *
     * Params:
     *      b = The array to be verified.
     *
     * Returns:
     *   Ternary.yes if the memory has been allocated by this allocator or Ternary.no if the memory is managed to other allocators.   
     */
    @trusted @nogc pure nothrow Ternary owns(const void[] b) shared {
        auto result = implIsOwn(b.ptr);

        if (result) {
            return Ternary.yes;
        } else {
            return Ternary.no;
        }
    }

    /**
     * Resolves a pointer to get the full memory block.
     *
     * Params:
     *      p = The pointer to resolve.
     *      result = The array with the full memory block.
     *
     * Returns:
     *   Ternary.no if the memory is managed to other allocators otherwise Ternary.yes.   
     */
    @trusted @nogc pure nothrow Ternary resolveInternalPointer(const void* p, ref void[] result) shared {
        import neomimalloc.c.mimalloc : mi_check_owned;
        import neomimalloc.c.mimalloc : mi_usable_size;

        auto pIsOwn = implIsOwn(p);

        if (!pIsOwn) {
            result = null;
            return Ternary.no;
        }

        auto sizeOfP = mi_usable_size(p);
        result = p[0 .. sizeOfP];
        return Ternary.yes;
    }

    /**
     * Deallocate the specified memory block
     *
     * Params:
     *      b = The memory block to be deallocated.
     *
     * Returns:
     *   false if the array is null, otherwise true. 
     */
    @system @nogc pure nothrow bool deallocate(void[] b) shared {
        import neomimalloc.c.mimalloc : mi_free;

        if (b is null) {
            return true;
        }

        mi_free(b.ptr);
        return true;
    }

    private @trusted @nogc pure nothrow bool implIsOwn(const void* p) shared {
        import neomimalloc.c.mimalloc : mi_check_owned;

        if (!p) {
            return false;
        }

        return mi_check_owned(b.ptr);
    }
}
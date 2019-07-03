// Written in the D programming language.
/**
This module provides low-level bindings with the mimalloc C interface
Copyright: Copyright 2019 Ernesto Castellotti <erny.castell@gmail.com>
License:   $(HTTP https://www.mozilla.org/en-US/MPL/2.0/, Mozilla Public License - Version 2.0).
Authors:   $(HTTP github.com/ErnyTech, Ernesto Castellotti)
*/
module neomimalloc.c.mimalloc;

import core.stdc.config : c_long;
import core.stdc.stdio: FILE;

extern(C) {
    /**
     * The mimalloc version
     */
    enum MI_MALLOC_VERSION = 100;

    /**
     * Internal use
     */
    enum MI_SMALL_WSIZE_MAX = 128;

    /**
     * Maximum size allowed for small allocations in mi_malloc_small and mi_zalloc_small (usually 128*sizeof(void*) (= 1KB on 64-bit systems))
     */
    enum MI_SMALL_SIZE_MAX = MI_SMALL_WSIZE_MAX * (void*).sizeof;

    /**
     * Type of deferred free functions.
     * 
     * Params:
     *      force = If true all outstanding items should be freed.
     *      heartbeat = A monotonically increasing count.
     *
     * Most detailed when using a debug build.
     */
    alias mi_deferred_free_fun = void function(bool force, ulong heartbeat);

    /**
     * Type of first-class heaps.
     *
     * A heap can only be used for (re)allocation in the thread that created this heap! Any allocated blocks can be freed by any other thread though.
     */
    struct mi_heap_t;

    /**
     * An area of heap space contains blocks of a single size.
     *
     * The bytes in freed blocks are committed - used.
     */
    struct mi_heap_area_t {
        void* blocks;       /** start of the area containing heap blocks */
        size_t reserved;    /** bytes reserved for this area (virtual) */
        size_t committed;   /** current available bytes for this area */
        size_t used;        /** bytes in use by allocated blocks */
        size_t block_size;  /** size in bytes of each block */
    }

    /**
     * Visitor function passed to mi_heap_visit_blocks()
     *
     * Returns:
     *      true if ok, false to stop visiting (i.e. break)
     * 
     * This function is always first called for every area with block as a NULL pointer. If visit_all_blocks was true, the function is then called for every allocated block in that area.
     */
    alias mi_block_visit_fun = bool function(const(mi_heap_t)* heap, 
                                            const(mi_heap_area_t)* area, 
                                            void* block, size_t block_size, 
                                            void* arg);

    /**
     * Runtime options.
     */
    enum mi_option_t {
        mi_option_page_reset = 0,       /** Reset page memory when it becomes free. */
        mi_option_cache_reset = 1,      /** Reset segment memory when a segment is cached. */
        mi_option_pool_commit = 2,      /** Commit segments in large pools. */
        mi_option_secure = 3,           
        mi_option_show_stats = 4,       /** Print statistics to stderr when the program is done. */
        mi_option_show_errors = 5,      /** Print error messages to stderr. */
        mi_option_verbose = 6,          /** Print verbose messages to stderr. */
        _mi_option_last = 7
}

    /**
     * Allocate size bytes.
     * 
     * Params:
     *      size = number of bytes to allocate.
     *
     * Returns:
     *      pointer to the allocated memory or NULL if out of memory. Returns a unique pointer if called with size 0.
     */
    @nogc pure @system nothrow void* mi_malloc(size_t size);

    /**
     * Allocate count elements of size bytes.
     * 
     * Params:
     *      count = The number of elements.
     *      size = The size of each element.
     *
     * Returns:
     *      A pointer to a block of count * size bytes, or NULL if out of memory or if count * size overflows.
     *
     * If there is no overflow, it behaves exactly like mi_malloc(p,count*size).
     */
    @nogc pure @system nothrow void* mi_mallocn(size_t count, size_t size);

    /**
     * Allocate zero-initialized count elements of size bytes.
     * 
     * Params:
     *      count = number of elements.
     *      size = size of each element.
     *
     * Returns:
     *      pointer to the allocated memory of size*count bytes, or NULL if either out of memory or when count*size overflows.
     *
     * Returns a unique pointer if called with either size or count of 0.
     */
    @nogc pure @system nothrow void* mi_calloc(size_t count, size_t size);

    /**
     * Re-allocate memory to newsize bytes.
     * 
     * Params:
     *      p = pointer to previously allocated memory (or NULL).
     *      newsize = the new required size in bytes.
     *
     * Returns:
     *      pointer to the re-allocated memory of newsize bytes, or NULL if out of memory. If NULL is returned, the pointer p is not freed. Otherwise the original pointer is either freed or returned as the reallocated result (in case it fits in-place with the new size). If the pointer p is NULL, it behaves as mi_malloc(newsize). If newsize is larger than the original size allocated for p, the bytes after size are uninitialized.
     */
    @nogc pure @system nothrow void* mi_realloc(void* p, size_t newsize);

    /**
     * Re-allocate memory to newsize bytes.
     * 
     * Params:
     *      p = pointer to previously allocated memory (or NULL).
     *      newsize = the new required size in bytes.
     *
     * Returns:
     *      pointer to the re-allocated memory of newsize bytes, or NULL if out of memory.
     *
     * In contrast to mi_realloc(), if NULL is returned, the original pointer p is freed (if it was not NULL itself). Otherwise the original pointer is either freed or returned as the reallocated result (in case it fits in-place with the new size). If the pointer p is NULL, it behaves as mi_malloc(newsize). If newsize is larger than the original size allocated for p, the bytes after size are uninitialized.
     */
    @nogc pure @system nothrow void* mi_reallocf(void* p, size_t newsize);

    /**
     * Re-allocate memory to count elements of size bytes.
     * 
     * Params:
     *      p = Pointer to a previously allocated block (or NULL).
     *      count = The number of elements.
     *      size = The size of each element.
     *
     * Returns:
     *      A pointer to a re-allocated block of count * size bytes, or NULL if out of memory or if count * size overflows.
     *
     * If there is no overflow, it behaves exactly like mi_realloc(p,count*size).
     */
    @nogc pure @system nothrow void* mi_reallocn(void* p, size_t count, size_t size);

    /**
     * Allocate zero-initialized size bytes.
     * 
     * Params:
     *      size = The size in bytes.
     *
     * Returns:
     *      Pointer to newly allocated zero initialized memory, or NULL if out of memory.
     */
    @nogc pure @system nothrow void* mi_zalloc(size_t size);
    
    /**
     * Reallocate memory to newsize bytes, with extra memory initialized to zero.
     * 
     * Params:
     *      p = Pointer to a previously allocated block (or NULL).
     *      newsize = The new required size in bytes.
     *
     * Returns:
     *      A pointer to a re-allocated block of newsize bytes, or NULL if out of memory.
     *
     * If the newsize is larger than the original allocated size of p, the extra bytes are initialized to zero.
     */
    @nogc pure @system nothrow void* mi_rezalloc(void* p, size_t newsize);

    /**
     * Re-allocate memory to newsize bytes.
     * 
     * Params:
     *      p = pointer to previously allocated memory (or NULL).
     *      newsize = the new required size in bytes.
     *
     * Returns:
     *      pointer to the re-allocated memory of newsize bytes, or NULL if out of memory. If NULL is returned, the pointer p is not freed. Otherwise the original pointer is either freed or returned as the reallocated result (in case it fits in-place with the new size). If the pointer p is NULL, it behaves as mi_malloc(newsize). If newsize is larger than the original size allocated for p, the bytes after size are uninitialized.
     */
    @nogc pure @system nothrow void* mi_recalloc(void* p, size_t count, size_t size);

    /**
     * Try to re-allocate memory to newsize bytes in place.
     * 
     * Params:
     *      p = pointer to previously allocated memory (or NULL).
     *      newsize = the new required size in bytes.
     *
     * Returns:
     *      pointer to the re-allocated memory of newsize bytes (always equal to p), or NULL if either out of memory or if the memory could not be expanded in place. If NULL is returned, the pointer p is not freed. Otherwise the original pointer is returned as the reallocated result since it fits in-place with the new size. If newsize is larger than the original size allocated for p, the bytes after size are uninitialized.
     */
    @nogc pure @system nothrow void* mi_expand(void* p, size_t newsize);

    /**
     * Free previously allocated memory.
     *
     * The pointer p must have been allocated before (or be NULL).
     * 
     * Params:
     *      p = pointer to free, or NULL.
     */
    @nogc pure @system nothrow void mi_free(void* p);

    /**
     * Allocate and duplicate a string.
     * 
     * Params:
     *      s = string to duplicate (or NULL).
     *
     * Returns:
     *      a pointer to newly allocated memory initialized to string s, or NULL if either out of memory or if s is NULL.
     *
     * Replacement for the standard strdup() such that mi_free() can be used on the returned result.
     */
    @nogc pure @system nothrow char* mi_strdup(const(char)* s);

    /**
     * Allocate and duplicate a string up to n bytes.
     * 
     * Params:
     *      s = string to duplicate (or NULL).
     *      n = maximum number of bytes to copy (excluding the terminating zero).
     *
     * Returns:
     *      a pointer to newly allocated memory initialized to string s up to the first n bytes (and always zero terminated), or NULL if either out of memory or if s is NULL.
     *
     * Replacement for the standard strndup() such that mi_free() can be used on the returned result.
     */
    @nogc pure @system nothrow char* mi_strndup(const(char)* s, size_t n);

    /**
     * Resolve a file path name.
     * 
     * Params:
     *      fname = File name.
     *      resolved_name = Should be NULL (but can also point to a buffer of at least PATH_MAX bytes).
     *
     * Returns:
     *      If successful a pointer to the resolved absolute file name, or NULL on failure (with errno set to the error code).
     *
     * If resolved_name was NULL, the returned result should be freed with mi_free().
     *
     * Replacement for the standard realpath() such that mi_free() can be used on the returned result (if resolved_name was NULL).
     */
    @nogc pure @system nothrow char* mi_realpath(const(char)* fname, char* resolved_name);

    /**
     * Allocate a small object.
     * 
     * Params:
     *      size = The size in bytes, can be at most MI_SMALL_SIZE_MAX.
     *
     * Returns:
     *      a pointer to newly allocated memory of at least size bytes, or NULL if out of memory. This function is meant for use in run-time systems for best performance and does not check if size was indeed small – use with care!
     */
    @nogc pure @system nothrow void* mi_malloc_small(size_t size);
    
    /**
     * Allocate a zero initialized small object.
     * 
     * Params:
     *      size = The size in bytes, can be at most MI_SMALL_SIZE_MAX.
     *
     * Returns:
     *      a pointer to newly allocated zero-initialized memory of at least size bytes, or NULL if out of memory. This function is meant for use in run-time systems for best performance and does not check if size was indeed small – use with care!
     */
    @nogc pure @system nothrow void* mi_zalloc_small (size_t size);
    
    /**
     * Return the available bytes in a memory block.
     * 
     * Params:
     *      p = Pointer to previously allocated memory (or NULL)
     *
     * Returns:
     *      Returns the available bytes in the memory block, or 0 if p was NULL.
     *
     * The returned size can be used to call mi_expand successfully. The returned size is always at least equal to the allocated size of p, and, in the current design, should be less than 16.7% more.
     */
    @nogc pure @system nothrow size_t mi_usable_size(void* p);
    
    /**
     * Return the used allocation size.
     * 
     * Params:
     *      size = The minimal required size in bytes.
     *
     * Returns:
     *      the size n that will be allocated, where n >= size.
     *
     * Generally, mi_usable_size(mi_malloc(size)) == mi_good_size(size). This can be used to reduce internal wasted space when allocating buffers for example.
     */
    @nogc pure @system nothrow size_t mi_good_size(size_t size);
    
    /**
     * Eagerly free memory.
     * 
     * Params:
     *      force = If true, aggressively return memory to the OS (can be expensive!)
     *
     * Regular code should not have to call this function. It can be beneficial in very narrow circumstances; in particular, when a long running thread allocates a lot of blocks that are freed by other threads it may improve resource usage by calling this every once in a while.
     */
    @nogc pure @system nothrow void mi_collect(bool force);
    
    /**
     * Print statistics.
     * 
     * Params:
     *      out_ = Output file. Use NULL for stderr.
     *
     * Most detailed when using a debug build.
     */
    @nogc pure @system nothrow void mi_stats_print(FILE* out_);
    
    /**
     * Reset statistics.
     */
    @nogc @system nothrow void mi_stats_reset();
    
    /**
     * Initialize mimalloc on a process
     */
    @nogc @system nothrow void mi_process_init();
    
    /**
     * Initialize mimalloc on a thread.
     *
     * Should not be used as on most systems (pthreads, windows) this is done automatically.
     */
    @nogc @system nothrow void mi_thread_init();
    
    /**
     * Uninitialize mimalloc on a thread.
     *
     * Should not be used as on most systems (pthreads, windows) this is done automatically. Ensures that any memory that is not freed yet (but will be freed by other threads in the future) is properly handled.
     */
    @nogc @system nothrow void mi_thread_done();
    
    /**
     * Print out heap statistics for this thread.
     * 
     * Params:
     *      out_ = Output file. Use NULL for stderr.
     *
     * Most detailed when using a debug build.
     */
    @nogc pure @system nothrow void mi_thread_stats_print(FILE* out_);
    
    /**
     * Register a deferred free function.
     * 
     * Params:
     *      deferred_free = Address of a deferred free-ing function or NULL to unregister.
     *
     * Some runtime systems use deferred free-ing, for example when using reference counting to limit the worst case free time. Such systems can register (re-entrant) deferred free function to free more memory on demand. When the force parameter is true all possible memory should be freed. The per-thread heartbeat parameter is monotonically increasing and guaranteed to be deterministic if the program allocates deterministically. The deferred_free function is guaranteed to be called deterministically after some number of allocations (regardless of freeing or available free memory). At most one deferred_free function can be active.
     */
    @nogc @system nothrow void mi_register_deferred_free(mi_deferred_free_fun deferred_free);

    /**
     * Allocate size bytes aligned by alignment.
     * 
     * Params:
     *      size = number of bytes to allocate.
     *      alignment = the minimal alignment of the allocated memory.
     *
     * Returns:
     *      pointer to the allocated memory or NULL if out of memory. The returned pointer is aligned by alignment, i.e. (uintptr_t)p % alignment == 0.
     *
     * Returns a unique pointer if called with size 0.
     */
    @nogc pure @system nothrow void* mi_malloc_aligned(size_t size, size_t alignment);
    
    /**
     * Allocate size bytes aligned by alignment at a specified offset.
     * 
     * Params:
     *      size = number of bytes to allocate.
     *      alignment = the minimal alignment of the allocated memory at offset.
     *      offset = the offset that should be aligned.
     *
     * Returns:
     *      pointer to the allocated memory or NULL if out of memory. The returned pointer is aligned by alignment at offset, i.e. ((uintptr_t)p + offset) % alignment == 0.
     *
     * Returns a unique pointer if called with size 0.
     */
    @nogc pure @system nothrow void* mi_malloc_aligned_at(size_t size, size_t alignment, size_t offset);
    
    /**
     * Allocate zero-initialized size bytes aligned by alignment.
     */
    @nogc pure @system nothrow void* mi_zalloc_aligned(size_t size, size_t alignment);
    
    /**
     * Allocate zero-initialized size bytes aligned by alignment at a specified offset.
     */
    @nogc pure @system nothrow void* mi_zalloc_aligned_at(size_t size, size_t alignment, size_t offset);
    
    /**
     * Allocate zero-initialized count elements of size bytes aligned by alignment.
     */
    @nogc pure @system nothrow void* mi_calloc_aligned(size_t count, size_t size, size_t alignment);
    
    /**
     * Allocate zero-initialized count elements of size bytes aligned by alignment at a specified offset.
     */
    void* mi_calloc_aligned_at(size_t count, size_t size, size_t alignment, size_t offset);
    
    /**
     * Re-allocate memory to newsize bytes aligned by alignment.
     */
    @nogc pure @system nothrow void* mi_realloc_aligned(void* p, size_t newsize, size_t alignment);
    
    /**
     * Re-allocate memory to newsize bytes aligned by alignment at a specified offset.
     */
    @nogc pure @system nothrow void* mi_realloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset);
    
    /**
     * Reallocate memory to newsize bytes, with extra memory initialized to zero aligned by alignment.
     */
    @nogc pure @system nothrow void* mi_rezalloc_aligned(void* p, size_t newsize, size_t alignment);
    
   /**
     * Reallocate memory to newsize bytes, with extra memory initialized to zero aligned by alignment at a specified offset.
     */
    @nogc pure @system nothrow void* mi_rezalloc_aligned_at(void* p, size_t newsize, size_t alignment, size_t offset);
    
    /**
     * Re-allocate memory to newsize bytes aligned by alignment.
     */
    @nogc pure @system nothrow void* mi_recalloc_aligned(void* p, size_t count, size_t size, size_t alignment);
    
    /**
     * Re-allocate memory to newsize bytes aligned by alignment at a specified offset.
     */
    @nogc pure @system nothrow void* mi_recalloc_aligned_at(void* p, size_t count, size_t size, size_t alignment, size_t offset);

    /**
     * Create a new heap that can be used for allocation.
     */
    @nogc pure @system nothrow mi_heap_t* mi_heap_new();
    
    /**
     * Delete a previously allocated heap.
     *
     * This will release resources and migrate any still allocated blocks in this heap (efficienty) to the default heap.
     * 
     * If heap is the default heap, the default heap is set to the backing heap.
     */
    @nogc pure @system nothrow void mi_heap_delete(mi_heap_t* heap);
    
    /**
     * Destroy a heap, freeing all its still allocated blocks.
     *
     * Use with care as this will free all blocks still allocated in the heap. However, this can be a very efficient way to free all heap memory in one go.
     * 
     * If heap is the default heap, the default heap is set to the backing heap.
     */
    @nogc pure @system nothrow void mi_heap_destroy(mi_heap_t* heap);
    
    /**
     * Set the default heap to use for mi_malloc() et al.
     * 
     * Params:
     *      heap = The new default heap.
     *
     * Returns:
     *      The previous default heap.
     */
    @nogc pure @system nothrow mi_heap_t* mi_heap_set_default(mi_heap_t* heap);
    
    /**
     * Get the default heap that is used for mi_malloc() et al.
     * 
     * Returns:
     *      The current default heap.
     */
    @nogc pure @system nothrow mi_heap_t* mi_heap_get_default();
    
    /**
     * Get the backing heap.
     *
     * The backing heap is the initial default heap for a thread and always available for allocations. It cannot be destroyed or deleted except by exiting the thread.
     */
    @nogc pure @system nothrow mi_heap_t* mi_heap_get_backing();
    
    /**
     * Eagerly free memory in specific heap.
     */ 
    @nogc pure @system nothrow void mi_heap_collect(mi_heap_t* heap, bool force);
    
    /**
     * Allocate in a specific heap.
     */
    @nogc pure @system nothrow void* mi_heap_malloc(mi_heap_t* heap, size_t size);

    /**
     * Allocate count elements in a specific heap.
     */
    @nogc pure @system nothrow void* mi_heap_mallocn(mi_heap_t* heap, size_t count, size_t size);

    /**
     * Allocate zero-initialized in a specific heap.
     */
    @nogc pure @system nothrow void* mi_heap_zalloc(mi_heap_t* heap, size_t size);
    
    /**
     * Allocate count zero-initialized elements in a specific heap.
     */
    @nogc pure @system nothrow void* mi_heap_calloc(mi_heap_t* heap, size_t count, size_t size);
    
    /**
     * Allocate a small object in a specific heap.
     */
    @nogc pure @system nothrow void* mi_heap_malloc_small(mi_heap_t* heap, size_t size);

    /**
     * Duplicate a string in a specific heap.
     */
    @nogc pure @system nothrow char* mi_heap_strdup(mi_heap_t* heap, const(char)* s);

    /**
     * Duplicate a string of at most length n in a specific heap.
     */
    @nogc pure @system nothrow char* mi_heap_strndup(mi_heap_t* heap, const(char)* s, size_t n);
    
    /**
     * Resolve a file path name using a specific heap to allocate the result.
     */
    @nogc pure @system nothrow char* mi_heap_realpath(mi_heap_t* heap, const(char)* fname, char* resolved_name);

    /**
     * Does a heap contain a pointer to a previously allocated block?
     * 
     * Params:
     *      heap = The heap.
     *      p = Pointer to a previously allocated block (in any heap)– cannot be some random pointer!
     *
     * Returns:
     *      true if the block pointed to by p is in the heap.
     */
    @nogc pure @system nothrow bool mi_heap_contains_block(mi_heap_t* heap, const(void)* p);
    
    /**
     * Check safely if any pointer is part of a heap.
     * 
     * Params:
     *      heap = The heap.
     *      p = Any pointer – not required to be previously allocated by us.
     *
     * Returns:
     *      true if p points to a block in heap.
     *
     * Note: expensive function, linear in the pages in the heap.
     */
    @nogc pure @system nothrow bool mi_heap_check_owned(mi_heap_t* heap, const(void)* p);
    
    /**
     * Check safely if any pointer is part of the default heap of this thread.
     * 
     * Params:
     *      p = Any pointer – not required to be previously allocated by us.
     *
     * Returns:
     *      true if p points to a block in default heap of this thread.
     *
     * Note: expensive function, linear in the pages in the heap.
     */
    @nogc pure @system nothrow bool mi_check_owned(const(void)* p);

    /**
     * Visit all areas and blocks in a heap.
     * 
     * Params:
     *      heap = The heap to visit.
     *      visit_all_blocks = If true visits all allocated blocks, otherwise visitor is only called for every heap area.
     *      visitor = This function is called for every area in the heap (with block as NULL). If visit_all_blocks is true, visitor is also called for every allocated block in every area (with block!=NULL). return false from this function to stop visiting early.
     *      arg = 	Extra argument passed to visitor.
     *
     * Returns:
     *      true if all areas and blocks were visited.
     */
    @nogc pure @system nothrow bool mi_heap_visit_blocks(const(mi_heap_t)* heap, bool visit_all_blocks, mi_block_visit_fun visitor, void* arg);

    /**
     * Set runtime behavior.
     */
    @nogc pure @system nothrow bool mi_option_is_enabled(mi_option_t option);

    /**
     * Set runtime behavior.
     */
    @nogc @system nothrow void mi_option_enable(mi_option_t option, bool enable);

    /**
     * Set runtime behavior.
     */
    @nogc @system nothrow void mi_option_enable_default(mi_option_t option, bool enable);

    /**
     * Set runtime behavior.
     */
    @nogc pure @system nothrow c_long mi_option_get(mi_option_t option);

    /**
     * Set runtime behavior.
     */
    @nogc @system nothrow void mi_option_set(mi_option_t option, c_long value);

    /**
     * Set runtime behavior.
     */
    @nogc @system nothrow void mi_option_set_default(mi_option_t option, c_long value);
}
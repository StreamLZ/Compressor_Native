/*
 * StreamLZ C API
 *
 * Single-call compress/decompress for StreamLZ (SLZ1 frame format).
 * Link against libstreamlz.a (static) or streamlz.dll/.so (dynamic).
 * Requires libc (the library uses c_allocator internally).
 *
 * Build:  zig build lib -Doptimize=ReleaseFast
 */

#ifndef STREAMLZ_H
#define STREAMLZ_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Compress `src_len` bytes from `src` into `dst`.
 *
 * `level` must be 1-11 (clamped if out of range).
 *   L1     — fastest compress, fast decompress
 *   L5     — balanced
 *   L9-L11 — best ratio, slow compress
 *
 * Returns the number of compressed bytes written to `dst`,
 * or 0 on failure (dst too small, allocation error).
 *
 * `dst` must be at least `slz_compress_bound(src_len)` bytes.
 */
size_t slz_compress(const void *src, size_t src_len,
                    void *dst, size_t dst_len,
                    int level);

/*
 * Decompress an SLZ1 frame from `src` into `dst`.
 *
 * Returns the number of decompressed bytes written to `dst`,
 * or 0 on failure (corrupt input, dst too small).
 *
 * `dst` must be at least `slz_content_size(src, src_len)` bytes
 * plus 64 bytes of safe-space padding.
 */
size_t slz_decompress(const void *src, size_t src_len,
                      void *dst, size_t dst_len);

/*
 * Returns the maximum compressed size for a given input length.
 * Use this to allocate the `dst` buffer for `slz_compress`.
 */
size_t slz_compress_bound(size_t src_len);

/*
 * Read the content size from an SLZ1 frame header.
 * Returns 0 if the header is invalid or content size is not present.
 */
uint64_t slz_content_size(const void *src, size_t src_len);

/*
 * Returns the library version string (e.g. "2.0.0").
 */
const char *slz_version_string(void);

#ifdef __cplusplus
}
#endif

#endif /* STREAMLZ_H */

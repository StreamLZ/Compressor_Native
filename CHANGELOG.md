# Changelog

## [2.1.0] — 2026-04-29

### Bug fixes

- **Fix L1 SC parallel decode corruption.** The greedy parser's
  initial `recent_offset = -8` and offset-8 fallback could match
  against the previous chunk's tail bytes, violating the SC contract.
  Serial decode was unaffected; parallel decode produced deterministic
  18-byte corruption. Fixed with window-base bounds checks in the
  parser prologue.
- **Fix MatchHasher2x aligned free.** The 64-byte-aligned hash table
  allocation was freed with default alignment, triggering a GPA error
  in debug/test builds.
- **Fix extendMatchForward byte tail.** The 8-byte + 4-byte comparison
  loop lacked a byte-by-byte tail, missing the last 1-3 matching bytes
  in short inputs.

### Performance

- **L1 ratio: 58.6% → 54.9%** (enwik8). u32 hash positions, 17-bit
  hash table (was 14-bit), simplified 2-way bounds check, content-first
  probe, on-the-fly skip computation.
- **L6-L8 ratio: 2.3pp improvement** via adaptive SC group sizing.
  Groups scale with file size (~16 groups per file) instead of fixed
  4-chunk groups. Larger groups give each parallel worker's match finder
  a wider window.
- **mmap I/O for compress and decompress.** Eliminates heap allocation
  and writeAll syscall overhead. Disk-to-disk L1 decompress: 37ms vs
  lzturbo's 46ms on enwik8.
- **High decoder bounds-check elimination.** Remove redundant
  `match_addr < dst_start` check from the fast path in
  `processOneToken` (~1.2% L9 decompress improvement).
- **Fast decoder split loop** (prior session). Bounds-check-free fast
  inner loop + safe tail for L1-L5 decode (+4.6% L1 single-thread).

### Build

- **Optional vendor libs** (`-Dbench=true`). Default build excludes
  zstd/lz4, shrinking binary from 2.1 MB to 1.3 MB and incremental
  builds from ~13s to ~200ms.
- **Static library caching.** zstd/lz4 compiled as separate static
  libraries so Zig source changes don't trigger C recompilation.

### Format

- **v2 frame header `sc_group_size` byte.** Replaces the v1 reserved
  byte. Encoders write the actual group size (1-255); decoders must
  use this value for SC group boundary calculations.

---

## [2.0.0] — 2026-04-20

Initial native (Zig) release. Full port of the C# StreamLZ library to
Zig 0.15.2 with byte-exact wire-format compatibility.

### Highlights

- **All 11 compression levels** (Fast L1-L5, High L6-L11) with compress
  and decompress at full parity with v1.
- **Parallel decompress** at all levels: SC group-parallel for L1,
  sidecar-based for L2-L5, SC group-parallel for L6-L8 (adaptive
  group size), two-phase parallel for L9-L11.
- **Dictionary support**: 7 built-in dictionaries (JSON, HTML, CSS, JS,
  XML, text, general) with auto-detection by file extension. Custom
  dictionary training via FASTCOVER algorithm. Zero-copy decompress
  (no memmove overhead).
- **128 MB dictionary window** for L11 (BT4 match finder).
- **Flag-driven CLI** (no subcommands): compress, decompress, benchmark,
  bench-all, decompress-bench, info, train, version.
- **297 unit tests** + 140 fixture roundtrips against C# reference output.
- **Fuzz harness** for decompressor safety testing.
- Streaming decompress to `std.Io.Writer` with XXH32 content-checksum
  verification.

### Performance (Arrow Lake-S, 24 cores, enwik8 100 MB)

- L1-L4 parallel decompress: 17-30 GB/s
- L5 parallel decompress: 10-13 GB/s
- L6-L8 SC group-parallel decompress: 15 GB/s
- L9-L11 two-phase parallel decompress: 2 GB/s
- L9 compress: 7.8 MB/s (SIMD hash probe + dual-bucket prefetch)

### Key optimizations over v1

- CMOV LIFO swap in Fast short-token loop
- Far-offset MOVDQU widening for medium/long match paths
- Conditional far-offset prefetch for L3-L5
- SIMD hash probe + dual-bucket prefetch for L9-L11 encoder
- Parallel resolveTokens for L9-L11 (+17-24% decompress)
- SC chunk grouping for L6-L8 (adaptive group size, ~16 groups per file)
- v2 sidecar frame format for L2-L5 parallel decode
- L1 SC per-chunk independence (no sidecar needed)

# Changelog

## [2.0.0] — 2026-04-20

Initial native (Zig) release. Full port of the C# StreamLZ library to
Zig 0.15.2 with byte-exact wire-format compatibility.

### Highlights

- **All 11 compression levels** (Fast L1-L5, High L6-L11) with compress
  and decompress at full parity with v1.
- **Parallel decompress** at all levels: sidecar-based for L1-L5,
  SC group-parallel for L6-L8, two-phase parallel for L9-L11.
- **Dictionary support**: 7 built-in dictionaries (JSON, HTML, CSS, JS,
  XML, text, general) with auto-detection by file extension. Custom
  dictionary training via FASTCOVER algorithm. Zero-copy decompress
  (no memmove overhead).
- **128 MB dictionary window** for L11 (BT4 match finder).
- **Flag-driven CLI** (no subcommands): compress, decompress, benchmark,
  bench-all, decompress-bench, info, train, version.
- **282 unit tests** + 140 fixture roundtrips against C# reference output.
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
- SC chunk grouping for L6-L8 (4x256KB groups)
- v2 sidecar frame format for L1-L5 parallel decode

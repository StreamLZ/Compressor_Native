# StreamLZ Native

Zig 0.15.2 implementation of [StreamLZ](https://github.com/StreamLZ/StreamLZ), a fast LZ77-family
compressor/decompressor. Covers all 11 compression levels (Fast L1-L5,
High L6-L11) with byte-exact wire-format compatibility with the C#
reference. Primary goal: **fast decompression** on consumer x86-64.

---

## Quick start

```
zig build -Doptimize=ReleaseFast
```

The CLI binary lands at `zig-out/bin/streamlz.exe` (Windows) or
`zig-out/bin/streamlz` (Linux/macOS).

```
streamlz file.txt                    # compress (default L3)
streamlz -l 9 file.txt              # compress at level 9
streamlz -d file.slz                # decompress
streamlz -b -l 5 file.txt           # benchmark level 5
streamlz -ba file.txt               # benchmark all L1-L11
streamlz -db file.slz               # decompress-only benchmark
streamlz -i file.slz                # frame/block info
streamlz --train -o dict.bin corpus/ # train custom dictionary
```

Dictionary flags: `-D name` selects a built-in dictionary, `--no-dict`
disables auto-detection.

---

## Build, test, fuzz

```
zig build -Doptimize=ReleaseFast                # release binary
zig build -Doptimize=ReleaseFast -Dstrip=false  # release + symbols (VTune)
zig build test --summary all                    # 282 unit tests
zig build safe                                  # ReleaseSafe build
zig build fuzz                                  # fuzz harness
```

Default target is `x86_64_v3` (Haswell+) for Intel/AMD portability.
Override with `-Dcpu=native` for host-specific tuning.

The fixture suite (`fixture_tests` + `encode_fixture_tests`) roundtrips
140 corpus files byte-exact against the C# reference. Generate fixtures
with `scripts/gen_fixtures.sh` and set `STREAMLZ_FIXTURES_DIR=./fixtures`
before running tests.

---

## Benchmarks

Intel Core Ultra 9 285K (Arrow Lake-S), Windows 11, `-Doptimize=ReleaseFast`.
Corpus: enwik8 (100 MB English text). Best of 3 runs.

### vs zstd and LZ4 (8 threads, enwik8)

Fair comparison — 8 threads for all compressors. LZ4 uses independent
4 MB blocks (same as the LZ4 CLI). All compressors use MT compress and
MT decompress where supported.

| Compressor | Ratio | Compress | Decompress | Notes |
|-----------|-------|----------|------------|-------|
| LZ4 MT    | 57.3% |  4,687 MB/s | 25,510 MB/s | |
| LZ4 HC 9 MT | 42.3% |    399 MB/s | 28,545 MB/s | |
| zstd 1    | 40.7% |  3,284 MB/s |  2,047 MB/s | decompress 1T [<sup>†</sup>][zstd-1t] |
| zstd 3    | 35.4% |  1,404 MB/s |  1,911 MB/s | decompress 1T [<sup>†</sup>][zstd-1t] |
| zstd 9    | 31.1% |    261 MB/s |  1,968 MB/s | decompress 1T [<sup>†</sup>][zstd-1t] |
| zstd 19   | 26.9% |    4.6 MB/s |  1,752 MB/s | decompress 1T [<sup>†</sup>][zstd-1t] |
| **SLZ L1**  | 58.6% |  2,681 MB/s | **30,653 MB/s** | |
| **SLZ L3**  | 56.5% |     83 MB/s | **20,904 MB/s** | compress 1T |
| **SLZ L5**  | 43.4% |     39 MB/s | **10,524 MB/s** | compress 1T |
| **SLZ L6**  | 31.4% |     41 MB/s |  **7,579 MB/s** | |
| **SLZ L8**  | 31.0% |     20 MB/s |  **7,783 MB/s** | |
| **SLZ L9**  | 27.4% |    6.8 MB/s |  2,127 MB/s | |
| **SLZ L11** | 25.6% |    1.1 MB/s |  1,900 MB/s | |

At the ~31% ratio tier: SLZ L6 decompresses **3.9x faster** than
zstd 9. At the ~57% tier: SLZ L1 decompresses **1.2x faster** than
LZ4 MT while compressing to a slightly smaller size. Where SLZ truly
dominates is against zstd: **15x faster decompress** at the fast tier
(SLZ L1 vs zstd 1) because zstd cannot parallelize decompression.

[zstd-1t]: https://github.com/facebook/zstd/issues/2470

> **Why is zstd decompress single-threaded?** Yann Collet (zstd/LZ4
> creator): *"[This is] due to a combination of being more difficult to
> do, and less critical, since decompression is already plenty fast with
> just a single thread (typically faster than SSD)."* — With PCIe 4.0 at
> 7 GB/s and PCIe 5.0 at 12+ GB/s, that no longer holds. StreamLZ
> decompresses in parallel at all levels.

### All levels (24 cores, enwik8)

Full-speed numbers with all 24 cores. `streamlz -ba -r 3 --no-dict`.

| Level | Compressed | Ratio | Compress | Decompress |
|-------|------------|-------|----------|------------|
| L1  | 58,634,412 | 58.6% | 4,765 MB/s | 35,111 MB/s |
| L2  | 56,882,861 | 56.9% |    86 MB/s | 30,271 MB/s |
| L3  | 56,522,955 | 56.5% |    82 MB/s | 29,649 MB/s |
| L4  | 53,963,934 | 54.0% |    82 MB/s | 34,592 MB/s |
| L5  | 43,376,368 | 43.4% |    39 MB/s | 11,203 MB/s |
| L6  | 31,376,255 | 31.4% |    82 MB/s | 15,501 MB/s |
| L7  | 31,299,037 | 31.3% |    57 MB/s | 15,701 MB/s |
| L8  | 30,997,739 | 31.0% |    40 MB/s | 15,354 MB/s |
| L9  | 27,430,880 | 27.4% |   7.5 MB/s |  1,576 MB/s |
| L10 | 27,280,109 | 27.3% |   7.4 MB/s |  2,177 MB/s |
| L11 | 25,550,460 | 25.6% |   1.2 MB/s |  1,438 MB/s |

L1 compress is parallel (SC, per-chunk workers); L2-L5 serial; L6-L11
parallel (High codec). All decompress is parallel.

---

## Dictionary support

7 built-in dictionaries (32 KB each, compiled into the binary): JSON,
HTML, CSS, JS, XML, plain text, and a general-purpose dictionary.

Dictionaries are auto-detected by file extension (`.json` → JSON,
`.html` → HTML, `.txt` → text, etc.). Unknown extensions fall back to
the general dictionary. Override with `-D name` or disable with
`--no-dict`.

Custom dictionaries can be trained from a corpus:

```
streamlz --train -o my_dict.bin path/to/corpus/
```

The trainer uses the FASTCOVER algorithm (based on zstd's dictionary
builder).

---

## What's missing (v2.1)

- **Streaming compress wrapper** (`StreamLzFrameCompressor` equivalent)
- **SlzStream** reader-writer pair
- **Level enum** (currently takes an integer)

These are API surface gaps; all compression/decompression functionality
is complete.

---

## Project layout

```
build.zig              build script
src/                   all Zig source
scripts/               fixture generation + fuzz harness
CodeWiki.md            source tree map, invariants, glossary
BENCHMARKS.md          historical benchmark numbers
CHANGELOG.md           release history
FORMAT.md              SLZ1 wire format specification
FailedExperiments.md   optimization dead-ends (valuable context)
SECURITY.md            security policy + fuzz testing
```

For the full source tree map, key invariants, and glossary, see
[CodeWiki.md](CodeWiki.md).

---

## License

MIT — same as the upstream StreamLZ project.

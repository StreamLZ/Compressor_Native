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

### vs zstd and LZ4 (single-threaded, enwik8)

Single-threaded comparison. All use independent 4 MB blocks.

| Compressor | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| LZ4       | 57.3% |     671 MB/s |  4,802 MB/s |
| LZ4 HC 9  | 42.3% |    52.1 MB/s |  4,674 MB/s |
| zstd 1    | 40.7% |     501 MB/s |  2,072 MB/s |
| zstd 3    | 35.6% |     297 MB/s |  2,007 MB/s |
| zstd 9    | 31.8% |    75.8 MB/s |  2,067 MB/s |
| zstd 19   | 29.0% |     4.2 MB/s |  1,962 MB/s |
| **SLZ L1**  | 54.9% |     407 MB/s |  **6,559 MB/s** |
| **SLZ L3**  | 53.4% |    71.6 MB/s |  **4,013 MB/s** |
| **SLZ L5**  | 43.4% |    40.2 MB/s |  **4,081 MB/s** |
| **SLZ L6**  | 27.4% |     3.2 MB/s |  1,061 MB/s |
| **SLZ L8**  | 25.5% |     0.9 MB/s |  1,048 MB/s |
| **SLZ L9**  | 27.4% |     3.3 MB/s |  1,012 MB/s |
| **SLZ L11** | 25.5% |     0.2 MB/s |    994 MB/s |

At the fast tier: SLZ L1 decompresses **3.2x faster** than zstd 1
(6.6 vs 2.1 GB/s) and **1.4x faster** than LZ4 (6.6 vs 4.8 GB/s).
SLZ L5 matches LZ4 HC 9's ratio (43.4% vs 42.3%) while decoding
nearly as fast (4.1 vs 4.7 GB/s). At the best-ratio tier:
SLZ L11 achieves 25.5% vs zstd 19's 29.0%.

[zstd-1t]: https://github.com/facebook/zstd/issues/2470#issuecomment-759613384

> **Why was zstd decompress historically single-threaded?** Yann Collet
> (zstd/LZ4 creator): *"[This is] due to a combination of being more
> difficult to do, and less critical, since decompression is already
> plenty fast with just a single thread (typically faster than SSD)."*
> [<sup>†</sup>][zstd-1t] — The numbers above give zstd the same
> block-parallel treatment as StreamLZ for a fair comparison. With
> PCIe 4.0 at 7 GB/s and PCIe 5.0 at 12+ GB/s, single-threaded
> decompress is no longer "faster than SSD."

### vs zstd and LZ4 (single-threaded, silesia 203 MB)

| Compressor | Ratio | Compress | Decompress |
|-----------|-------|----------|------------|
| LZ4       | 47.5% |     915 MB/s |  5,246 MB/s |
| LZ4 HC 9  | 36.7% |    55.7 MB/s |  5,338 MB/s |
| zstd 1    | 34.7% |     676 MB/s |  2,245 MB/s |
| zstd 3    | 31.5% |     413 MB/s |  2,096 MB/s |
| zstd 9    | 28.3% |     102 MB/s |  2,297 MB/s |
| zstd 19   | 25.8% |     5.3 MB/s |  2,054 MB/s |
| **SLZ L1**  | 45.8% |     632 MB/s |  **7,168 MB/s** |
| **SLZ L3**  | 45.6% |    86.6 MB/s |  **3,522 MB/s** |
| **SLZ L5**  | 37.6% |    50.2 MB/s |  **4,735 MB/s** |
| **SLZ L6**  | 24.9% |     4.9 MB/s |  1,308 MB/s |
| **SLZ L8**  | 24.3% |     1.2 MB/s |  1,321 MB/s |
| **SLZ L9**  | 24.9% |     5.0 MB/s |  1,202 MB/s |
| **SLZ L11** | 24.3% |     0.3 MB/s |  1,218 MB/s |

### All levels (24 cores, enwik8)

Full-speed numbers with all 24 cores. `streamlz -ba -r 3 --no-dict`.

| Level | Compressed | Ratio | Compress | Decompress |
|-------|------------|-------|----------|------------|
| L1  | 58,635,288 | 58.6% | 4,515 MB/s | 31,550 MB/s |
| L2  | 56,883,810 | 56.9% |    86 MB/s | 33,483 MB/s |
| L3  | 56,523,932 | 56.5% |    82 MB/s | 30,431 MB/s |
| L4  | 53,964,914 | 54.0% |    82 MB/s | 31,316 MB/s |
| L5  | 43,377,247 | 43.4% |    40 MB/s | 10,084 MB/s |
| L6  | 31,376,255 | 31.4% |    69 MB/s | 15,210 MB/s |
| L7  | 31,299,037 | 31.3% |    51 MB/s | 15,193 MB/s |
| L8  | 30,997,739 | 31.0% |    35 MB/s | 15,236 MB/s |
| L9  | 27,430,880 | 27.4% |   7.6 MB/s |  2,051 MB/s |
| L10 | 27,280,109 | 27.3% |   7.3 MB/s |  2,057 MB/s |
| L11 | 25,550,460 | 25.6% |   1.3 MB/s |  2,019 MB/s |

L1 compress is parallel (SC, per-chunk workers); L2-L5 compress serial;
L6-L11 compress parallel (High codec). All decompress is parallel:
L1 SC group-parallel, L2-L5 sidecar parallel, L6-L8 SC group-parallel
(adaptive group size), L9-L11 two-phase parallel.

### All levels (24 cores, enwik9 — 1 GB)

| Level | Compressed | Ratio | Compress | Decompress |
|-------|------------|-------|----------|------------|
| L1  | 522,968,434 | 52.3% | 5,610 MB/s | 31,122 MB/s |
| L2  | 507,756,352 | 50.8% |    82 MB/s | 30,608 MB/s |
| L3  | 504,805,210 | 50.5% |    79 MB/s | 31,068 MB/s |
| L4  | 483,591,236 | 48.4% |    81 MB/s | 31,167 MB/s |
| L5  | 392,752,692 | 39.3% |    39 MB/s | 10,977 MB/s |
| L6  | 277,816,941 | 27.8% |    83 MB/s | 17,932 MB/s |
| L7  | 275,526,412 | 27.6% |    48 MB/s | 18,351 MB/s |
| L8  | 272,710,834 | 27.3% |    33 MB/s | 19,025 MB/s |
| L9  | 240,990,881 | 24.1% |   7.8 MB/s |  3,435 MB/s |
| L10 | 237,327,055 | 23.7% |   7.4 MB/s |  3,524 MB/s |
| L11 | 205,685,427 | 20.6% |   0.9 MB/s |  2,493 MB/s |

### All levels (24 cores, silesia — 203 MB)

| Level | Compressed | Ratio | Compress | Decompress |
|-------|------------|-------|----------|------------|
| L1  | 100,278,034 | 47.1% | 5,937 MB/s | 33,982 MB/s |
| L2  |  98,521,402 | 46.3% |   110 MB/s | 33,011 MB/s |
| L3  |  98,112,746 | 46.1% |   103 MB/s | 32,981 MB/s |
| L4  |  94,748,347 | 44.5% |   102 MB/s | 34,128 MB/s |
| L5  |  79,927,683 | 37.6% |    50 MB/s | 10,717 MB/s |
| L6  |  56,843,696 | 26.7% |    89 MB/s | 18,923 MB/s |
| L7  |  56,669,194 | 26.6% |    42 MB/s | 18,817 MB/s |
| L8  |  55,938,668 | 26.3% |    26 MB/s | 19,747 MB/s |
| L9  |  52,915,951 | 24.9% |    12 MB/s |  2,480 MB/s |
| L10 |  52,678,794 | 24.8% |    11 MB/s |  2,831 MB/s |
| L11 |  51,331,020 | 24.1% |   3.1 MB/s |  3,259 MB/s |

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

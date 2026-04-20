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

Intel Core Ultra 9 285K (Arrow Lake-S), 24 cores, Windows 11.
`-Doptimize=ReleaseFast`. All numbers from `streamlz -ba -r 3 --no-dict`.

### enwik8 (100 MB English text)

| Level | Compressed | Ratio | Compress | Decompress |
|-------|------------|-------|----------|------------|
| L1  | 58,634,412 | 58.6% | 4,765 MB/s | 35,111 MB/s |
| L2  | 56,882,861 | 56.9% |  85.7 MB/s | 30,271 MB/s |
| L3  | 56,522,955 | 56.5% |  82.1 MB/s | 29,649 MB/s |
| L4  | 53,963,934 | 54.0% |  82.0 MB/s | 34,592 MB/s |
| L5  | 43,376,368 | 43.4% |  39.1 MB/s | 11,203 MB/s |
| L6  | 31,376,255 | 31.4% |  82.0 MB/s | 15,501 MB/s |
| L7  | 31,299,037 | 31.3% |  57.2 MB/s | 15,701 MB/s |
| L8  | 30,997,739 | 31.0% |  40.3 MB/s | 15,354 MB/s |
| L9  | 27,430,880 | 27.4% |   7.5 MB/s |  1,576 MB/s |
| L10 | 27,280,109 | 27.3% |   7.4 MB/s |  2,177 MB/s |
| L11 | 25,550,460 | 25.6% |   1.2 MB/s |  1,438 MB/s |

All numbers use parallel dispatch (24 cores). L1 compress is parallel
(SC mode, per-chunk workers); L2-L5 compress is serial; L6-L11
compress is parallel (High codec).

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

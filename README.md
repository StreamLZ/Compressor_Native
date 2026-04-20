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
| L1  | 59,102,816 | 59.1% |  98.6 MB/s | 34,947 MB/s |
| L2  | 57,298,758 | 57.3% |  85.9 MB/s | 34,778 MB/s |
| L3  | 56,937,334 | 56.9% |  81.8 MB/s | 32,548 MB/s |
| L4  | 54,303,437 | 54.3% |  81.7 MB/s | 33,298 MB/s |
| L5  | 43,112,965 | 43.1% |  39.3 MB/s | 13,009 MB/s |
| L6  | 31,793,212 | 31.8% |  77.5 MB/s | 15,306 MB/s |
| L7  | 31,717,862 | 31.7% |  55.1 MB/s | 15,706 MB/s |
| L8  | 31,436,039 | 31.4% |  39.0 MB/s | 15,408 MB/s |
| L9  | 28,396,689 | 28.4% |   7.8 MB/s |  2,136 MB/s |
| L10 | 28,253,307 | 28.3% |   7.6 MB/s |  2,187 MB/s |
| L11 | 26,850,856 | 26.9% |   1.2 MB/s |  2,033 MB/s |

All decompress numbers use parallel dispatch (24 cores). Compress is
serial for L1-L5 (Fast codec) and parallel for L6-L11 (High codec).

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

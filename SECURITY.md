# Security Policy

## Safe for Untrusted Input

StreamLZ is designed to handle untrusted compressed data safely. The
decompression pipeline validates all header fields, chunk boundaries,
entropy table parameters, and pointer arithmetic before accessing memory.

For maximum safety when processing untrusted data:
- Enable content checksums (`use_content_checksum = true` in Options)
- Use the framed APIs (`compressFramed` / `decompressFramed`)
- Set `num_threads` conservatively in server environments
- Set `max_decompressed_size` to a reasonable limit

## Testing

The decoder is fuzz-tested with brute-force mutation across all codec
levels (L1 through L11) and the framed API. Mutations include bit flips,
truncation, zeroed sections, duplicated blocks, and randomized headers.
Build with `zig build fuzz` and run with `zig-out/bin/streamlz_fuzz`.

Runtime safety checks are enabled in `ReleaseSafe` builds — use this
mode for production deployments handling untrusted input.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it privately via
GitHub's Security Advisories:

https://github.com/StreamLZ/Compressor_Native/security/advisories/new

Do not open a public issue for security vulnerabilities.

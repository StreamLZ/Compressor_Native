const std = @import("std");
const builtin = @import("builtin");

// Build steps
// -----------
//   zig build          Default ReleaseFast build + install
//   zig build run      Run the streamlz CLI
//   zig build test     Run unit tests
//   zig build safe     Build with ReleaseSafe (bounds + overflow checks)
//   zig build fuzz     Build fuzz_decompress harness (ReleaseSafe)
//                      Usage: zig-out/bin/fuzz-decompress <input-file>

pub fn build(b: *std.Build) void {
    // Default the x86_64 CPU model to `x86_64_v3` (AVX2 baseline,
    // covering all Intel since Haswell 2013 and all AMD since
    // Excavator 2015). Without this, Zig defaults to `-mcpu=native`
    // which produces a binary that uses host-CPU-specific instructions
    // (BMI2, ADX, AVX-VNNI, etc.) and crashes with STATUS_ILLEGAL_
    // INSTRUCTION (0xc000001d) on older or different-vendor CPUs.
    //
    // Override with `-Dcpu=native` for maximum local perf, or
    // `-Dcpu=baseline` for SSE2-only (most portable).
    const default_query: std.Target.Query = if (builtin.target.cpu.arch == .x86_64) .{
        .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v3 },
    } else .{};
    const target = b.standardTargetOptions(.{ .default_target = default_query });
    const optimize = b.standardOptimizeOption(.{});

    // -Dstrip=false keeps debug info even in ReleaseFast so profilers
    // (VTune, samply, etc.) can attribute samples to source lines.
    const strip = b.option(bool, "strip", "Strip debug symbols (default: optimize-mode default)");

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });

    const exe = b.addExecutable(.{
        .name = "streamlz",
        .root_module = root_module,
    });
    // Link libc so std.heap.c_allocator is available — used by the
    // decoder's per-chunk token-array fallback (matches C#'s
    // NativeMemory.Alloc, ~100x faster than page_allocator).
    exe.linkLibC();
    addVendorLibs(b, exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the streamlz CLI");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{ .root_module = root_module });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // ---- ReleaseSafe build step ----
    // Enables runtime safety checks (bounds, overflow) at moderate
    // performance cost. Useful for CI and testing against untrusted data.
    const safe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .strip = strip,
    });
    const safe_exe = b.addExecutable(.{
        .name = "streamlz-safe",
        .root_module = safe_module,
    });
    safe_exe.linkLibC();
    addVendorLibs(b, safe_exe);
    const safe_install = b.addInstallArtifact(safe_exe, .{});
    const safe_step = b.step("safe", "Build with ReleaseSafe (bounds + overflow checks)");
    safe_step.dependOn(&safe_install.step);

    // ---- Fuzz harness for the decompressor ----
    // Reads stdin as compressed input, calls decompressFramed, swallows
    // decode errors. Panics only on memory safety violations (which
    // ReleaseSafe catches). Feed with: afl-fuzz, honggfuzz, or manual
    // corpus via  `zig build fuzz && echo ... | ./zig-out/bin/fuzz-decompress`
    const streamlz_module = b.createModule(.{
        .root_source_file = b.path("src/streamlz.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .strip = strip,
    });
    const fuzz_module = b.createModule(.{
        .root_source_file = b.path("scripts/fuzz_decompress.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
        .strip = strip,
        .imports = &.{
            .{ .name = "streamlz", .module = streamlz_module },
        },
    });
    const fuzz_exe = b.addExecutable(.{
        .name = "fuzz-decompress",
        .root_module = fuzz_module,
    });
    fuzz_exe.linkLibC();
    const fuzz_install = b.addInstallArtifact(fuzz_exe, .{});
    const fuzz_step = b.step("fuzz", "Build fuzz_decompress harness (ReleaseSafe)");
    fuzz_step.dependOn(&fuzz_install.step);
}

fn addVendorLibs(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const c_flags = &.{ "-DXXH_NAMESPACE=ZSTD_", "-DZSTD_DISABLE_ASM", "-DZSTD_MULTITHREAD" };

    // ---- zstd (v1.5.7) ----
    exe.addIncludePath(b.path("vendor/zstd"));
    exe.addIncludePath(b.path("vendor/zstd/common"));
    exe.addCSourceFiles(.{ .files = &.{
        "vendor/zstd/common/debug.c",
        "vendor/zstd/common/entropy_common.c",
        "vendor/zstd/common/error_private.c",
        "vendor/zstd/common/fse_decompress.c",
        "vendor/zstd/common/pool.c",
        "vendor/zstd/common/threading.c",
        "vendor/zstd/common/xxhash.c",
        "vendor/zstd/common/zstd_common.c",
        "vendor/zstd/compress/fse_compress.c",
        "vendor/zstd/compress/hist.c",
        "vendor/zstd/compress/huf_compress.c",
        "vendor/zstd/compress/zstd_compress.c",
        "vendor/zstd/compress/zstd_compress_literals.c",
        "vendor/zstd/compress/zstd_compress_sequences.c",
        "vendor/zstd/compress/zstd_compress_superblock.c",
        "vendor/zstd/compress/zstd_double_fast.c",
        "vendor/zstd/compress/zstd_fast.c",
        "vendor/zstd/compress/zstd_lazy.c",
        "vendor/zstd/compress/zstd_ldm.c",
        "vendor/zstd/compress/zstd_opt.c",
        "vendor/zstd/compress/zstd_preSplit.c",
        "vendor/zstd/compress/zstdmt_compress.c",
        "vendor/zstd/decompress/huf_decompress.c",
        "vendor/zstd/decompress/zstd_ddict.c",
        "vendor/zstd/decompress/zstd_decompress.c",
        "vendor/zstd/decompress/zstd_decompress_block.c",
    }, .flags = c_flags });

    // ---- LZ4 (v1.10.0) ----
    exe.addIncludePath(b.path("vendor/lz4"));
    exe.addCSourceFiles(.{ .files = &.{
        "vendor/lz4/lz4.c",
        "vendor/lz4/lz4hc.c",
    }, .flags = &.{} });
}

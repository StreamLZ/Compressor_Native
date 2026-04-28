//! Cross-platform memory-mapped file I/O.
//!
//! Provides `mapFileRead` / `mapFileReadWrite` for zero-copy file access.
//! On Windows uses CreateFileMappingW + MapViewOfFile (not in Zig 0.15
//! kernel32 bindings). On POSIX uses std.posix.mmap.

const std = @import("std");
const builtin = @import("builtin");
const is_windows = builtin.os.tag == .windows;

// ────────────────────────────────────────────────────────────
//  Windows externs
// ────────────────────────────────────────────────────────────

const HANDLE = std.os.windows.HANDLE;
const DWORD = u32;
const BOOL = std.os.windows.BOOL;

extern "kernel32" fn CreateFileMappingW(
    hFile: HANDLE,
    lpAttributes: ?*anyopaque,
    flProtect: DWORD,
    dwMaxSizeHigh: DWORD,
    dwMaxSizeLow: DWORD,
    lpName: ?[*:0]const u16,
) callconv(.winapi) ?HANDLE;

extern "kernel32" fn MapViewOfFile(
    hMap: HANDLE,
    dwAccess: DWORD,
    dwOffHi: DWORD,
    dwOffLo: DWORD,
    dwBytes: usize,
) callconv(.winapi) ?*anyopaque;

extern "kernel32" fn UnmapViewOfFile(lpBase: *const anyopaque) callconv(.winapi) BOOL;
extern "kernel32" fn CloseHandle(h: HANDLE) callconv(.winapi) BOOL;

const PAGE_READONLY: DWORD = 0x02;
const PAGE_READWRITE: DWORD = 0x04;
const FILE_MAP_READ: DWORD = 0x04;
const FILE_MAP_WRITE: DWORD = 0x02;

// ────────────────────────────────────────────────────────────
//  Mapped file handle (holds cleanup state)
// ────────────────────────────────────────────────────────────

pub const MappedFile = struct {
    ptr: [*]u8,
    len: usize,
    // Windows needs the mapping handle for cleanup
    map_handle: if (is_windows) ?HANDLE else void,

    pub fn sliceConst(self: MappedFile) []const u8 {
        return self.ptr[0..self.len];
    }

    pub fn slice(self: MappedFile) []u8 {
        return self.ptr[0..self.len];
    }

    pub fn unmap(self: *MappedFile) void {
        if (is_windows) {
            _ = UnmapViewOfFile(@ptrCast(self.ptr));
            if (self.map_handle) |h| _ = CloseHandle(h);
        } else {
            const aligned: [*]align(std.mem.page_size) u8 = @alignCast(self.ptr);
            std.posix.munmap(aligned[0..self.len]);
        }
    }
};

// ────────────────────────────────────────────────────────────
//  Public API
// ────────────────────────────────────────────────────────────

pub fn mapFileRead(file: std.fs.File, size: usize) ?MappedFile {
    if (is_windows) {
        const map_h = CreateFileMappingW(file.handle, null, PAGE_READONLY, 0, 0, null) orelse return null;
        const view = MapViewOfFile(map_h, FILE_MAP_READ, 0, 0, 0) orelse {
            _ = CloseHandle(map_h);
            return null;
        };
        return .{
            .ptr = @ptrCast(view),
            .len = size,
            .map_handle = map_h,
        };
    } else {
        const result = std.posix.mmap(null, size, std.posix.PROT.READ, .{ .TYPE = .SHARED }, file.handle, 0);
        const ptr = result catch return null;
        return .{
            .ptr = @ptrCast(ptr),
            .len = size,
            .map_handle = {},
        };
    }
}

pub fn mapFileReadWrite(file: std.fs.File, size: usize) ?MappedFile {
    if (is_windows) {
        const size_hi: DWORD = @intCast(size >> 32);
        const size_lo: DWORD = @intCast(size & 0xFFFFFFFF);
        const map_h = CreateFileMappingW(file.handle, null, PAGE_READWRITE, size_hi, size_lo, null) orelse return null;
        const view = MapViewOfFile(map_h, FILE_MAP_READ | FILE_MAP_WRITE, 0, 0, 0) orelse {
            _ = CloseHandle(map_h);
            return null;
        };
        return .{
            .ptr = @ptrCast(view),
            .len = size,
            .map_handle = map_h,
        };
    } else {
        const result = std.posix.mmap(null, size, std.posix.PROT.READ | std.posix.PROT.WRITE, .{ .TYPE = .SHARED }, file.handle, 0);
        const ptr = result catch return null;
        return .{
            .ptr = @ptrCast(ptr),
            .len = size,
            .map_handle = {},
        };
    }
}

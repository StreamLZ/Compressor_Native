const c = @cImport({
    @cInclude("lz4.h");
    @cInclude("lz4hc.h");
});

pub fn compress(dst: []u8, src: []const u8) !usize {
    const ret = c.LZ4_compress_default(
        @ptrCast(src.ptr),
        @ptrCast(dst.ptr),
        @intCast(src.len),
        @intCast(dst.len),
    );
    if (ret <= 0) return error.Lz4CompressError;
    return @intCast(ret);
}

pub fn compressHc(dst: []u8, src: []const u8, level: c_int) !usize {
    const ret = c.LZ4_compress_HC(
        @ptrCast(src.ptr),
        @ptrCast(dst.ptr),
        @intCast(src.len),
        @intCast(dst.len),
        level,
    );
    if (ret <= 0) return error.Lz4CompressError;
    return @intCast(ret);
}

pub fn decompress(dst: []u8, src: []const u8, original_size: usize) !usize {
    const ret = c.LZ4_decompress_safe(
        @ptrCast(src.ptr),
        @ptrCast(dst.ptr),
        @intCast(src.len),
        @intCast(original_size),
    );
    if (ret < 0) return error.Lz4DecompressError;
    return @intCast(ret);
}

pub fn compressBound(src_size: usize) usize {
    return @intCast(c.LZ4_compressBound(@intCast(src_size)));
}

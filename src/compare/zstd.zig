const c = @cImport({
    @cInclude("zstd.h");
});

pub fn compress(dst: []u8, src: []const u8, level: c_int) !usize {
    const ret = c.ZSTD_compress(dst.ptr, dst.len, src.ptr, src.len, level);
    if (c.ZSTD_isError(ret) != 0) return error.ZstdCompressError;
    return ret;
}

pub fn compressMt(dst: []u8, src: []const u8, level: c_int, threads: c_int) !usize {
    const cctx = c.ZSTD_createCCtx() orelse return error.ZstdAllocError;
    defer _ = c.ZSTD_freeCCtx(cctx);
    _ = c.ZSTD_CCtx_setParameter(cctx, c.ZSTD_c_compressionLevel, level);
    _ = c.ZSTD_CCtx_setParameter(cctx, c.ZSTD_c_nbWorkers, threads);
    const ret = c.ZSTD_compress2(cctx, dst.ptr, dst.len, src.ptr, src.len);
    if (c.ZSTD_isError(ret) != 0) return error.ZstdCompressError;
    return ret;
}

pub fn decompress(dst: []u8, src: []const u8) !usize {
    const ret = c.ZSTD_decompress(dst.ptr, dst.len, src.ptr, src.len);
    if (c.ZSTD_isError(ret) != 0) return error.ZstdDecompressError;
    return ret;
}

pub fn compressBound(src_size: usize) usize {
    return c.ZSTD_compressBound(src_size);
}

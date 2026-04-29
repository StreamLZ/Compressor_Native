cmake_minimum_required(VERSION 3.14)
project(streamlz VERSION 2.0.0 LANGUAGES C)

# Build the static library via Zig
set(ZIG_BUILD_DIR "${CMAKE_BINARY_DIR}/zig-out")

add_custom_command(
    OUTPUT "${ZIG_BUILD_DIR}/lib/streamlz.lib"
           "${ZIG_BUILD_DIR}/include/streamlz.h"
    COMMAND zig build lib -Doptimize=ReleaseFast
            "--prefix=${ZIG_BUILD_DIR}"
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
    COMMENT "Building libstreamlz via zig build"
)

add_custom_target(zig_build ALL
    DEPENDS "${ZIG_BUILD_DIR}/lib/streamlz.lib"
)

# Import as a static library
add_library(streamlz STATIC IMPORTED GLOBAL)
set_target_properties(streamlz PROPERTIES
    IMPORTED_LOCATION "${ZIG_BUILD_DIR}/lib/streamlz.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${ZIG_BUILD_DIR}/include"
)
add_dependencies(streamlz zig_build)

# Install
install(FILES "${ZIG_BUILD_DIR}/lib/streamlz.lib"
        DESTINATION lib)
install(FILES "${ZIG_BUILD_DIR}/include/streamlz.h"
        DESTINATION include)

# pkg-config
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/streamlz.pc.in"
    "${CMAKE_BINARY_DIR}/streamlz.pc"
    @ONLY
)
set(PREFIX "${CMAKE_INSTALL_PREFIX}")
configure_file(streamlz.pc.in "${CMAKE_BINARY_DIR}/streamlz.pc" @ONLY)
install(FILES "${CMAKE_BINARY_DIR}/streamlz.pc"
        DESTINATION lib/pkgconfig)

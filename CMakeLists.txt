# Solar2D Hello Plugin build configuration, used for every native platform.
# Builds a library that exposes luaopen_<plugin name>: a static archive on iOS
# and tvOS, a shared library everywhere else.
#
# string(JSON ...) requires CMake 3.19 or newer.
cmake_minimum_required(VERSION 3.19)

# Plugin identity lives only in metadata.json. Derive the binary/symbol name from it
# (Lua module name with dots replaced by underscores, e.g. plugin.hello -> plugin_hello).
file(READ "${CMAKE_CURRENT_LIST_DIR}/metadata.json" PLUGIN_METADATA)
string(JSON PLUGIN_NAME_DOTTED GET "${PLUGIN_METADATA}" pluginName)
string(REPLACE "." "_" PLUGIN_TARGET "${PLUGIN_NAME_DOTTED}")

project(${PLUGIN_TARGET} C)

set(CMAKE_C_STANDARD 99)

# Configurable paths for Lua 5.1; the bundled headers are the fallback.
set(LUA_INCLUDE_DIR "" CACHE PATH "Path to Lua 5.1 headers")
set(LUA_LIBRARY "" CACHE FILEPATH "Path to Lua 5.1 library (for linking on Windows)")

# The only source list: every platform's build compiles these files.
set(PLUGIN_SOURCES
    src/plugin_hello.c
)

# iOS and tvOS apps link plugins statically (via staticLibs in metadata.lua);
# every other platform loads a shared library at runtime.
set(PLUGIN_APPLE_STATIC FALSE)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS" OR CMAKE_SYSTEM_NAME STREQUAL "tvOS")
    set(PLUGIN_APPLE_STATIC TRUE)
endif()

if(PLUGIN_APPLE_STATIC)
    add_library(${PLUGIN_TARGET} STATIC ${PLUGIN_SOURCES})
else()
    add_library(${PLUGIN_TARGET} SHARED ${PLUGIN_SOURCES})
endif()

# The luaopen_ entry point name is pasted from this define at compile time.
target_compile_definitions(${PLUGIN_TARGET} PRIVATE CORONA_PLUGIN_NAME=${PLUGIN_TARGET})

if(LUA_INCLUDE_DIR AND EXISTS "${LUA_INCLUDE_DIR}")
    target_include_directories(${PLUGIN_TARGET} PRIVATE "${LUA_INCLUDE_DIR}")
else()
    target_include_directories(${PLUGIN_TARGET} PRIVATE external/lua51)
endif()

if(PLUGIN_APPLE_STATIC)
    # lib<name>.a via the default prefix and suffix.
    set_target_properties(${PLUGIN_TARGET} PROPERTIES OUTPUT_NAME "${PLUGIN_TARGET}")

elseif(WIN32)
    # Windows: link against the Lua 5.1 import library.
    if(LUA_LIBRARY AND EXISTS "${LUA_LIBRARY}")
        target_link_libraries(${PLUGIN_TARGET} PRIVATE "${LUA_LIBRARY}")
    else()
        find_library(LUA51_LIB NAMES lua51 lua5.1 lua)
        if(LUA51_LIB)
            target_link_libraries(${PLUGIN_TARGET} PRIVATE ${LUA51_LIB})
        else()
            message(WARNING "Lua library not found. Set -DLUA_LIBRARY=<path to lua51.lib>")
        endif()
    endif()

    set_target_properties(${PLUGIN_TARGET} PROPERTIES
        OUTPUT_NAME "${PLUGIN_TARGET}"
        PREFIX ""
        SUFFIX ".dll"
    )

elseif(ANDROID)
    # lib<name>.so via the default prefix; the jniLibs/<abi>/ nesting happens
    # in the packaging step.
    set_target_properties(${PLUGIN_TARGET} PROPERTIES OUTPUT_NAME "${PLUGIN_TARGET}")

    # Android 15+ devices can use 16 KB memory pages, where a library with
    # 4 KB-aligned LOAD segments fails to load. NDK r28+ aligns by default,
    # r27 and older need these flags.
    target_link_options(${PLUGIN_TARGET} PRIVATE
        "-Wl,-z,max-page-size=16384"
        "-Wl,-z,common-page-size=16384"
    )

elseif(APPLE)
    # macOS: Lua symbols resolve against the host process at load time.
    target_link_options(${PLUGIN_TARGET} PRIVATE "-undefined" "dynamic_lookup")

    set_target_properties(${PLUGIN_TARGET} PROPERTIES
        OUTPUT_NAME "${PLUGIN_TARGET}"
        PREFIX ""
        SUFFIX ".dylib"
    )

elseif(UNIX)
    # Linux: undefined Lua symbols in a .so are allowed by default and resolve
    # against the host process at load time.
    set_target_properties(${PLUGIN_TARGET} PROPERTIES
        OUTPUT_NAME "${PLUGIN_TARGET}"
        PREFIX ""
        SUFFIX ".so"
    )
endif()

# Hide internal symbols so only luaopen_<plugin name> (marked with PLUGIN_EXPORT) stays visible.
if(NOT WIN32)
    set_target_properties(${PLUGIN_TARGET} PROPERTIES
        C_VISIBILITY_PRESET hidden
    )
endif()

install(TARGETS ${PLUGIN_TARGET}
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

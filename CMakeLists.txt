cmake_minimum_required(VERSION 3.10)

project(plugin_hello C)

# Solar2D Hello Plugin build configuration
# Builds a shared library (.dll / .dylib / .so) for Solar2D

set(CMAKE_C_STANDARD 99)

# Configurable paths for Lua 5.1
set(LUA_INCLUDE_DIR "" CACHE PATH "Path to Lua 5.1 headers")
set(LUA_LIBRARY "" CACHE FILEPATH "Path to Lua 5.1 library (for linking on Windows)")

# Source files
set(PLUGIN_SOURCES
    src/plugin_hello.c
)

# Create shared library
add_library(plugin_hello SHARED ${PLUGIN_SOURCES})

# Lua headers
if(LUA_INCLUDE_DIR AND EXISTS "${LUA_INCLUDE_DIR}")
    target_include_directories(plugin_hello PRIVATE "${LUA_INCLUDE_DIR}")
else()
    # Fall back to bundled headers
    target_include_directories(plugin_hello PRIVATE external/lua51)
endif()

# Platform-specific configuration
if(WIN32)
    # Windows: link against Lua 5.1 library
    if(LUA_LIBRARY AND EXISTS "${LUA_LIBRARY}")
        target_link_libraries(plugin_hello PRIVATE "${LUA_LIBRARY}")
    else()
        find_library(LUA51_LIB NAMES lua51 lua5.1 lua)
        if(LUA51_LIB)
            target_link_libraries(plugin_hello PRIVATE ${LUA51_LIB})
        else()
            message(WARNING "Lua library not found. Set -DLUA_LIBRARY=<path to lua51.lib>")
        endif()
    endif()

    # Output: plugin_hello.dll
    set_target_properties(plugin_hello PROPERTIES
        OUTPUT_NAME "plugin_hello"
        PREFIX ""
        SUFFIX ".dll"
    )

elseif(APPLE)
    # macOS: allow undefined Lua symbols (resolved at runtime by Solar2D host)
    target_link_options(plugin_hello PRIVATE "-undefined" "dynamic_lookup")

    # Output: plugin_hello.dylib
    set_target_properties(plugin_hello PROPERTIES
        OUTPUT_NAME "plugin_hello"
        PREFIX ""
        SUFFIX ".dylib"
    )

elseif(UNIX)
    # Linux: allow undefined Lua symbols (resolved at runtime by Solar2D host)
    target_link_options(plugin_hello PRIVATE "-Wl,--allow-shlib-undefined")

    # Output: plugin_hello.so
    set_target_properties(plugin_hello PROPERTIES
        OUTPUT_NAME "plugin_hello"
        PREFIX ""
        SUFFIX ".so"
    )
endif()

# Hide internal symbols, only export luaopen_plugin_hello (marked with PLUGIN_EXPORT)
if(NOT WIN32)
    set_target_properties(plugin_hello PROPERTIES
        C_VISIBILITY_PRESET hidden
    )
endif()

# Install targets
install(TARGETS plugin_hello
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

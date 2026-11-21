/*
 * plugin_hello.c
 * Solar2D Hello Plugin - Native Plugin Sample
 *
 * A minimal native plugin that demonstrates the structure of a Solar2D
 * plugin without any platform-specific dependencies. The single function
 * hello.getGreeting() returns a greeting string that includes the
 * platform name and the current local time.
 */

#include "lua.h"
#include "lauxlib.h"

#include <time.h>
#include <stdio.h>

/* Export macro for symbol visibility */
#ifdef _WIN32
    #define PLUGIN_EXPORT __declspec(dllexport)
#elif defined(__GNUC__) || defined(__clang__)
    #define PLUGIN_EXPORT __attribute__((visibility("default")))
#else
    #define PLUGIN_EXPORT
#endif

/* Entry point must be luaopen_<binary name>; CORONA_PLUGIN_NAME is supplied at build
   time from metadata.json (dots to underscores). The fallback lets this file compile alone. */
#ifndef CORONA_PLUGIN_NAME
    #define CORONA_PLUGIN_NAME plugin_hello
#endif
#define PLUGIN_PASTE_(a, b) a ## b
#define PLUGIN_PASTE(a, b) PLUGIN_PASTE_(a, b)
#define PLUGIN_LUAOPEN PLUGIN_PASTE(luaopen_, CORONA_PLUGIN_NAME)

/* Determine platform name at compile time */
#if defined(_WIN32)
    #define PLATFORM_NAME "Windows"
#elif defined(__APPLE__)
    #include <TargetConditionals.h>
    /* TARGET_OS_IPHONE is also set on tvOS, so tvOS is checked first */
    #if TARGET_OS_TV
        #define PLATFORM_NAME "tvOS"
    #elif TARGET_OS_IPHONE
        #define PLATFORM_NAME "iOS"
    #else
        #define PLATFORM_NAME "macOS"
    #endif
#elif defined(__ANDROID__)
    #define PLATFORM_NAME "Android"
#elif defined(__linux__)
    #define PLATFORM_NAME "Linux"
#else
    #define PLATFORM_NAME "Unknown"
#endif

/* hello.getGreeting()
 * Returns "Hello from <platform>! The time is currently HH:MM:SS." */
static int hello_getGreeting(lua_State *L)
{
    char timeStr[16];
    char greeting[128];
    time_t now;
    struct tm *local;

    /* Get current local time formatted as HH:MM:SS */
    now = time(NULL);
    local = localtime(&now);
    strftime(timeStr, sizeof(timeStr), "%H:%M:%S", local);

    /* Build the greeting string */
    snprintf(greeting, sizeof(greeting),
        "Hello from %s! The time is currently %s.", PLATFORM_NAME, timeStr);

    lua_pushstring(L, greeting);
    return 1;
}

static const luaL_Reg kHelloFunctions[] =
{
    { "getGreeting", hello_getGreeting },
    { NULL, NULL }
};

/* Plugin entry point: luaopen_plugin_hello by default (see CORONA_PLUGIN_NAME above) */
PLUGIN_EXPORT
int PLUGIN_LUAOPEN(lua_State *L)
{
    /* NULL name keeps the module out of _G; require() uses the returned table */
    lua_newtable(L);
    luaL_register(L, NULL, kHelloFunctions);
    return 1;
}

/*
 * plugin_hello.c
 * Solar2D Hello Plugin - Native Plugin Sample
 *
 * A minimal native plugin that demonstrates the structure of a Solar2D
 * plugin without any platform-specific dependencies. The single function
 * hello.getGreeting() returns a greeting string that includes the
 * platform name and the current local time.
 *
 * Copyright (c) 2026 Eetu Rantanen
 * MIT License
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

/* Determine platform name at compile time */
#if defined(_WIN32)
    #define PLATFORM_NAME "Windows"
#elif defined(__APPLE__)
    #include <TargetConditionals.h>
    #if TARGET_OS_IPHONE
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

/* Plugin entry point */
PLUGIN_EXPORT
int luaopen_plugin_hello(lua_State *L)
{
    /* NULL name keeps the module out of _G; require() uses the returned table */
    lua_newtable(L);
    luaL_register(L, NULL, kHelloFunctions);
    return 1;
}

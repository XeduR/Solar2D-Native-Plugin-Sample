# Solar2D Hello Plugin - Native Plugin Sample

A beginner-friendly sample project demonstrating how to build a native [Solar2D](https://solar2d.com/) plugin from scratch.

This plugin has a single function — `hello.getGreeting()` — that returns a greeting string including the platform name and the current time. It is intentionally minimal so that the project structure, build configuration, and platform integration are easy to follow without the complexity of a real-world plugin.

If you are looking for a more complete example, see the [Solar2D Cursor](https://github.com/XeduR/Solar2D-Cursor) plugin, which this sample project is modeled after.

| Platform | Status | Implementation |
|----------|--------|----------------|
| Windows  | Full   | C (MSVC)       |
| macOS    | Full   | C (Clang)      |
| Linux    | Full   | C (GCC)        |
| iOS      | Full   | C (Clang)      |
| Android  | Full   | C (NDK)        |
| HTML5    | Full   | JavaScript     |

## Getting Started

For build instructions, installation, and plugin distribution setup, see **[BUILDING.md](BUILDING.md)**.

## Usage

Require the plugin in your Lua code:

```lua
local hello = require( "plugin.hello" )
```

Add the plugin to your `build.settings`:

```lua
settings =
{
    plugins =
    {
        ["plugin.hello"] =
        {
            publisherId = "com.xedur",
        },
    },
}
```

## API

### hello.getGreeting()

Returns a greeting string that includes the platform name and the current local time.

```lua
local message = hello.getGreeting()
print( message )
-- "Hello from Windows! The time is currently 14:30:45."
```

**Returns**: A string in the format `"Hello from <platform>! The time is currently HH:MM:SS."`

Platform names: Windows, macOS, Linux, iOS, Android, HTML5, Lua (fallback).

## Example

```lua
local hello = require( "plugin.hello" )

local greeting = hello.getGreeting()
print( greeting )
```

A sample project is in the [`sample/`](sample/) directory.

## Project Structure

```
src/                          Native C source code
  plugin_hello.c               Single source file for all native platforms
web/                          HTML5 JavaScript plugin
lua/                          Lua stub for unsupported platforms
solar2d-native/               Solar2D Native SDK project files
external/lua51/               Bundled Lua 5.1 headers
sample/                       Sample Solar2D project
CMakeLists.txt                Standalone CMake build
.github/workflows/build.yml   CI/CD (GitHub Actions)
```

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Eetu Rantanen

# Solar2D Hello Plugin - Native Plugin Sample

A beginner-friendly sample project demonstrating how to build a native [Solar2D](https://solar2d.com/) plugin from scratch.

This plugin has a single function, `hello.getGreeting()`, that returns a greeting string including the platform name and the current time. It is intentionally minimal so that the project structure, build configuration, and platform integration are easy to follow without the complexity of a real-world plugin.

If you are looking for a more complete example of a real-world plugin, see [Solar2D Cursor](https://github.com/XeduR/Solar2D-Cursor), which is built based on this sample project.

| Platform | Status | Implementation |
|----------|--------|----------------|
| Windows  | Full   | C (MSVC)       |
| macOS    | Full   | C (Clang)      |
| Linux    | Full   | C (GCC)        |
| iOS      | Full   | C (Clang)      |
| tvOS     | Full   | C (Clang)      |
| Android  | Full   | C (NDK)        |
| HTML5    | Full   | JavaScript     |

Solar2D also runs on Nintendo Switch, but building plugins for it requires the NDA-gated Nintendo SDK, so this sample does not cover it.

## Getting Started

On Windows, run [`local_build.bat`](local_build.bat) to build the plugin and install it for both the Simulator and Windows app builds. All other platforms are built by GitHub Actions. For details, installation, and plugin distribution setup, see **[BUILDING.md](BUILDING.md)**.

To adapt this sample into your own plugin, edit [`metadata.json`](metadata.json) (plugin name, publisher id, versions, and platforms); every build path reads it, so you do not rename files or touch the build scripts. The sample project in [`sample/`](sample/) declares the default identity, so update it too if you rename the plugin. See [Configuring the Plugin](BUILDING.md#configuring-the-plugin).

To submit a finished plugin to the Solar2D Free Plugin Directory, see **[PUBLISHING.md](PUBLISHING.md)**.

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

Platform names: Windows, macOS, Linux, iOS, tvOS, Android, HTML5. The Lua fallback stub returns an availability notice instead of the timed greeting.

## Example

```lua
local hello = require( "plugin.hello" )

local greeting = hello.getGreeting()
print( greeting )
```

A sample project is in the [`sample/`](sample/) directory.

## Project Structure

```
metadata.json                 Single source of truth: plugin name, publisher, versions, platforms
src/                          Native C source code
  plugin_hello.c               Single source file for all native platforms
web/                          HTML5 JavaScript plugin
lua/                          Lua stub for unsupported platforms
external/lua51/               Bundled Lua 5.1 headers
local_build.bat               Windows local build (sets up CMake and MSVC if needed)
tools/                        Metadata reader and the iOS, tvOS, and Android build scripts run by CI
sample/                       Sample Solar2D project
CMakeLists.txt                CMake build for every native platform
.github/workflows/build.yml   CI/CD (GitHub Actions)
```

## License

MIT License. See [LICENSE](LICENSE) for details.

Copyright (c) 2026 Eetu Rantanen

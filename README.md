# Solar2D Hello Plugin - Native Plugin Sample

A beginner-friendly sample project demonstrating how to build a native [Solar2D](https://solar2d.com/) plugin from scratch.

This plugin has a single function, `getGreeting()`, that returns a greeting string including the platform name and the current time. It is intentionally minimal so that the project structure, build configuration, and platform integration are easy to follow without the complexity of a real-world plugin.

For real-world plugins that use the same build system, see [Solar2D Plugins](https://github.com/XeduR/Solar2D-Plugins).

## Features

- One C source file builds for Windows, macOS, Linux, iOS, tvOS, and Android through a single `CMakeLists.txt`.
- A JavaScript implementation covers HTML5, and a Lua fallback covers platforms without a native build.
- `metadata.json` holds the plugin name, publisher id, versions, and platform list, and every build path reads it.
- `local_build.bat` builds the plugin on Windows and installs it for the Simulator and for Windows app builds.
- A GitHub Actions workflow builds each platform, checks each binary, runs a Lua test of the plugin, packages the results as `data.tgz` tarballs, and creates a GitHub Release.

## Platform Support

| Platform | Status |
| --- | --- |
| Windows | Supported |
| macOS | Supported |
| Linux | Supported |
| iOS | Supported |
| tvOS | Supported |
| Android | Supported |
| HTML5 | Supported through a separate JavaScript implementation |
| Nintendo Switch | Not supported. Building plugins for Switch needs the NDA-gated Nintendo SDK. |

## Installation

`plugin.hello` is not in the Solar2D Free Plugin Directory, so adding it to `build.settings` does not install it. Build and install it yourself first:

- On Windows, run [`local_build.bat`](local_build.bat). It builds the plugin and installs it for the Simulator and for Windows app builds.
- For any other platform, run the `Build Plugin` workflow from the Actions tab of your fork and install its `plugin-tarballs` artifact.

[BUILDING.md](BUILDING.md) covers both, along with self-hosted distribution.

Then add the plugin to `build.settings`:

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

## Usage

```lua
local hello = require( "plugin.hello" )

print( hello.getGreeting() )
-- Hello from Windows! The time is currently 14:30:45.
```

`getGreeting()` returns a string in the format `Hello from <platform>! The time is currently HH:MM:SS.`, using the local time. On a platform without a native build, the Lua fallback returns a notice that the native plugin is not available.

To see the plugin run, open the project in [`sample/`](sample/) in the Simulator after installing the plugin. See [Testing with the Sample Project](BUILDING.md#testing-with-the-sample-project).

## Making Your Own Plugin

To turn the sample into your own plugin, edit [`metadata.json`](metadata.json): plugin name, publisher id, versions, and platforms. Every build path reads it, so you do not rename files or edit the build scripts. The sample project in [`sample/`](sample/) declares the default identity, so update it too if you rename the plugin. See [Configuring the Plugin](BUILDING.md#configuring-the-plugin).

To submit a finished plugin to the Solar2D Free Plugin Directory, see [PUBLISHING.md](PUBLISHING.md).

## Author

[© 2026 Eetu Rantanen](https://www.erantanen.com)

## License

[MIT](LICENSE)

Bundled third-party code:

- Lua 5.1 headers: MIT

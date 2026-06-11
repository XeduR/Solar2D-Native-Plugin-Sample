# Building and Installing

This guide covers how to build the plugin from source, where to place the built files, and how to set up plugin distribution so that Solar2D can find the plugin when building your apps.

If you are new to Solar2D plugin development, start with the [Overview](#overview) section to understand how the pieces fit together, then follow the steps relevant to your platform.

## Table of Contents

- [Overview](#overview)
- [Naming Convention](#naming-convention)
- [Building the Plugin](#building-the-plugin)
  - [Solar2D Native](#solar2d-native)
  - [CMake](#cmake)
  - [GitHub Actions](#github-actions)
- [Installing for the Simulator](#installing-for-the-simulator)
- [Installing for App Builds](#installing-for-app-builds)
- [Self-Hosted Distribution](#self-hosted-distribution)
- [Testing with the Sample Project](#testing-with-the-sample-project)

---

## Overview

A Solar2D native plugin is a shared library (`.dll`, `.dylib`, or `.so`) that exposes a `luaopen_<module>` function. When Lua calls `require("plugin.hello")`, Solar2D loads the shared library and calls `luaopen_plugin_hello()`, which registers the plugin's functions.

There are two contexts where Solar2D needs to find your plugin:

1. **The Simulator.** When you press "play" in the Solar2D Simulator, it loads plugin binaries from a platform-specific plugins directory on your machine.

2. **App builds.** When you build your app for distribution (e.g. "File > Build > Windows"), Solar2D's build process looks for plugins in the `Solar2DPlugins` directory, packaged as `data.tgz` tarballs. This is a separate mechanism from the Simulator.

You need to set up both if you want to test in the Simulator and also build standalone apps.

There are three ways to build the native plugin:

| Method | Requires Solar2D SDK | CI/CD ready | Auto-installs to Simulator |
|--------|---------------------|-------------|---------------------------|
| [Solar2D Native](#solar2d-native) | Yes | No | Yes |
| [CMake](#cmake) | No | Yes | No |
| [GitHub Actions](#github-actions) | No | Yes | No |

Building produces a binary for each platform:

| Platform | Output File |
|----------|-------------|
| Windows  | `plugin_hello.dll` |
| macOS    | `plugin_hello.dylib` |
| Linux    | `plugin_hello.so` |
| iOS      | `libplugin_hello.a` (static library) |
| Android  | `libplugin_hello.so` (per ABI) |

The HTML5 platform uses a pure JavaScript file (`web/plugin_hello.js`) instead of a compiled binary, so no build step is needed for it.

The `lua/` directory contains a Lua stub (`plugin_hello.lua`) that acts as a fallback on platforms where the native plugin is not available. It returns a valid module with a stub `getGreeting()` function. No build step is needed for this either.

---

## Naming Convention

Solar2D plugins follow a specific naming convention. The Lua module name uses dots (`plugin.hello`) but the binary filename uses underscores (`plugin_hello.dll`). This matches how Lua's `require` resolves C module names: `require("plugin.hello")` looks for `luaopen_plugin_hello` in a file named `plugin_hello.dll` (or `.dylib`/`.so`).

All output files must use underscores, not dots. If you are adapting this repo for your own plugin, make sure the output name in `CMakeLists.txt`, `Plugin.vcxproj`, and the build scripts all use underscores.

---

## Building the Plugin

### Solar2D Native

Uses the official build toolchain bundled with Solar2D. Best for local development since it builds the plugin and copies it directly into the Simulator's plugin directory.

#### Prerequisites

- Solar2D installed (the installer sets the `CORONA_ROOT` environment variable)
- **Windows**: Visual Studio 2022 with the "Desktop development with C++" workload. VS2019 works too, but the project targets the v143 toolset, so retarget the solution to v142 first (right-click the solution > Retarget solution)
- **macOS**: Xcode Command Line Tools (`xcode-select --install`)
- **Linux**: GCC
- **iOS**: Xcode Command Line Tools (`xcode-select --install`)
- **Android**: Android NDK (set `ANDROID_NDK_HOME` environment variable)

Verify `CORONA_ROOT` is set:
```bash
# Windows (cmd)
echo %CORONA_ROOT%
# Should print something like: C:\Program Files (x86)\Corona Labs\Corona\Native

# macOS / Linux
echo $CORONA_ROOT
```

#### Windows

**Visual Studio:**
1. Open `solar2d-native/win32/Plugin.sln`
2. Select **Release | Win32**
3. Build (Ctrl+Shift+B)

**Command line:**
```cmd
cd solar2d-native\win32
build.bat Release
```

The post-build step automatically copies `plugin_hello.dll` to the Simulator plugins directory.

F5 debugging from Visual Studio launches the Corona Simulator via the `CORONA_PATH` environment variable, which the Solar2D installer sets to the install folder (e.g. `C:\Program Files (x86)\Corona Labs\Corona`).

#### macOS

```bash
cd solar2d-native/mac
./build.sh
```

Builds a universal binary (x86_64 + arm64) and copies `plugin_hello.dylib` to the Simulator plugins directory.

#### Linux

```bash
cd solar2d-native/linux
./build.sh
```

Output: `plugin_hello.so` in the current directory.

#### iOS

```bash
cd solar2d-native/ios
./build.sh
```

Builds static libraries for iOS device (arm64) and iOS Simulator (arm64 + x86_64). Output is in `device/` and `simulator/` subdirectories.

#### Android

```bash
cd solar2d-native/android
./build.sh
```

Builds shared libraries for all Android ABIs (armeabi-v7a, arm64-v8a, x86, x86_64). Requires the Android NDK. Output is in per-ABI subdirectories.

---

### CMake

Standalone build using CMake. Does not require the Solar2D SDK. Uses the bundled Lua 5.1 headers in `external/lua51/`. Lua symbols are resolved at runtime by the Solar2D host application, so you do not need a full Lua installation.

#### Prerequisites

- CMake 3.10+
- C compiler (MSVC, GCC, or Clang)

#### Windows

On Windows, the plugin must link against a Lua 5.1 import library. The repo includes a `.def` file to generate one without needing full Lua sources:

```cmd
:: From a Visual Studio Developer Command Prompt
lib /def:external\lua51\lua51.def /out:external\lua51\lua51.lib /machine:x86

mkdir build && cd build
cmake .. -A Win32 -DLUA_LIBRARY=../external/lua51/lua51.lib
cmake --build . --config Release
```

Alternatively, if you have the Solar2D Native SDK installed, you can point CMake at its Lua library:

```cmd
mkdir build && cd build
cmake .. -A Win32 ^
  -DLUA_INCLUDE_DIR="%CORONA_ROOT%\Corona\shared\include\lua" ^
  -DLUA_LIBRARY="%CORONA_ROOT%\Corona\win\lib\lua.lib"
cmake --build . --config Release
```

Output: `build/Release/plugin_hello.dll`

#### macOS

No Lua library needed. Symbols resolve at runtime via `-undefined dynamic_lookup`.

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

Output: `build/plugin_hello.dylib`

For a universal binary (x86_64 + arm64):
```bash
cmake -B build-x64 -DCMAKE_OSX_ARCHITECTURES=x86_64 -DCMAKE_BUILD_TYPE=Release
cmake --build build-x64 --config Release
cmake -B build-arm64 -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_BUILD_TYPE=Release
cmake --build build-arm64 --config Release
lipo -create build-x64/plugin_hello.dylib build-arm64/plugin_hello.dylib -output plugin_hello.dylib
```

#### Linux

No Lua library needed. Undefined symbols are allowed by default when linking a Linux shared library; they resolve at runtime from the Solar2D host.

```bash
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
```

Output: `build/plugin_hello.so`

#### CMake Options

| Variable | Type | Description |
|----------|------|-------------|
| `LUA_INCLUDE_DIR` | PATH | Path to Lua 5.1 headers (default: `external/lua51/`) |
| `LUA_LIBRARY` | FILEPATH | Path to Lua 5.1 `.lib` file (Windows only) |

---

### GitHub Actions

The repository includes a CI workflow at `.github/workflows/build.yml` that builds the plugin for all platforms. It runs manually via `workflow_dispatch` or automatically when a `v*` tag is pushed.

#### What it does

1. **Windows.** Generates a Lua import library from the bundled `.def` file, then builds `plugin_hello.dll` via CMake (x86).
2. **macOS.** Builds separately for x86_64 and arm64, then combines into a universal binary with `lipo`.
3. **Linux.** Builds `plugin_hello.so` via CMake.
4. **iOS.** Builds `libplugin_hello.a` static libraries for device (arm64) and Simulator (arm64 + x86_64).
5. **Android.** Builds `libplugin_hello.so` for all ABIs (armeabi-v7a, arm64-v8a, x86, x86_64) using the Android NDK.
6. **Package.** Assembles the full plugin distribution:
   - Copies the compiled binaries from steps 1–5.
   - Copies the HTML5 JavaScript plugin from `web/plugin_hello.js` and its `web/metadata.lua`.
   - Copies the Lua fallback stub from `lua/plugin_hello.lua` and its `lua/metadata.lua`.
   - Generates a `metadata.lua` for each platform.
   - Creates per-platform `data.tgz` tarballs for self-hosted distribution.

#### Artifacts

Every successful workflow run produces these downloadable artifacts:

| Artifact | Contents |
|----------|----------|
| `win32-sim` | `plugin_hello.dll` |
| `mac-sim` | `plugin_hello.dylib` (universal) |
| `linux` | `plugin_hello.so` |
| `iphone` | `libplugin_hello.a` (device, arm64) |
| `iphone-sim` | `libplugin_hello.a` (simulator, arm64 + x86_64) |
| `android` | `libplugin_hello.so` (all ABIs) |
| `plugin-distribution` | Full plugin directory structure with raw files for all platforms |
| `plugin-tarballs` | Ready-to-install `data.tgz` tarballs in `com.xedur/plugin.hello/<platform>/` structure |

The `plugin-tarballs` artifact is the most useful one for app builds. Extract it and copy the `com.xedur` folder directly into your `Solar2DPlugins` directory. See [Installing for App Builds](#installing-for-app-builds) for details.

#### Releases

Pushing a tag matching `v*` (e.g., `v1.0.0`) automatically creates a GitHub Release with the platform tarballs attached.

```bash
git tag v1.0.0
git push origin v1.0.0
```

#### Updating the Plugin Version

The `PLUGIN_VERSION` value controls the version directory name in the distribution structure. Manual runs can set it via the `plugin_version` input on the workflow dispatch form; tag-triggered runs use the default defined at the top of the workflow. Update the default when targeting a different Solar2D build number.

---

## Installing for the Simulator

The Solar2D Simulator loads plugins at runtime from a platform-specific directory. Copy the built binary there:

| Platform | Destination |
|----------|-------------|
| Windows  | `%APPDATA%\Corona Labs\Corona Simulator\Plugins\plugin_hello.dll` |
| macOS    | `~/Library/Application Support/Corona/Simulator/Plugins/plugin_hello.dylib` |
| Linux    | `~/.Solar2D/Plugins/plugin_hello.so` |

The Solar2D Native build scripts do this automatically. If you built with CMake or GitHub Actions, you need to copy the file manually.

This is sufficient for testing your plugin in the Simulator. However, when you build your app for distribution (e.g. "File > Build > Windows"), the Simulator plugins directory is **not** used. You need to set up the `Solar2DPlugins` directory for that, as described in the next section.

---

## Installing for App Builds

When Solar2D builds your app for a target platform (Windows desktop, macOS, HTML5, etc.), it looks for plugins in the `Solar2DPlugins` directory. Each plugin needs to be packaged as a `data.tgz` tarball inside a platform-specific subdirectory.

### Using the plugin-tarballs artifact (recommended)

The easiest approach. Download the `plugin-tarballs` artifact from a GitHub Actions workflow run, extract the zip, and copy the `com.xedur` folder into your `Solar2DPlugins` directory:

| OS | Solar2DPlugins Path |
|----|---------------------|
| Windows | `%APPDATA%\Solar2DPlugins\` |
| macOS | `~/Solar2DPlugins/` |
| Linux | `~/Solar2DPlugins/` |

The artifact already contains the correct directory structure:

```
com.xedur/plugin.hello/
  win32-sim/data.tgz
  mac-sim/data.tgz
  linux/data.tgz
  iphone/data.tgz
  iphone-sim/data.tgz
  android/data.tgz
  web/data.tgz
  lua/data.tgz
```

### Manual setup from local builds

If you built locally instead of using GitHub Actions, you need to create the tarballs yourself.

Each platform needs a directory containing a plugin binary and a `metadata.lua`. The `metadata.lua` file tells Solar2D what kind of plugin it is. Desktop and Android native plugins use `format = "sharedLibrary"`. iOS plugins use `format = "staticLibrary"` and must also list the library name in `staticLibs` (without the `lib` prefix, e.g. `staticLibs = { "plugin_hello" }`); without it, the iOS build never links the static library and `require` fails at runtime. The HTML5 plugin uses `format = "javascript"`; the HTML5 loader resolves the plugin purely by filename (`plugin_hello.js`), so the format string only matters on the packaging side. The Lua stub uses `format = "lua"`. See the `web/metadata.lua` and `lua/metadata.lua` files in this repository for examples.

Android needs one extra level: the `.so` files must sit under `jniLibs/<abi>/` inside the tarball, next to `metadata.lua`. The Android app build only collects plugin native libraries from `jniLibs/` paths; bare `<abi>/` directories get mis-collected into a broken armeabi-v7a-only layout. The `android` directory should look like this before tarring:

```
android/
  metadata.lua
  jniLibs/
    armeabi-v7a/libplugin_hello.so
    arm64-v8a/libplugin_hello.so
    x86/libplugin_hello.so
    x86_64/libplugin_hello.so
```

For each platform directory, create a `data.tgz` tarball containing its files:

```bash
cd win32-sim && tar -czf data.tgz * && cd ..
cd mac-sim && tar -czf data.tgz * && cd ..
cd linux && tar -czf data.tgz * && cd ..
cd iphone && tar -czf data.tgz * && cd ..
cd iphone-sim && tar -czf data.tgz * && cd ..
cd android && tar -czf data.tgz * && cd ..
cd web && tar -czf data.tgz * && cd ..
cd lua && tar -czf data.tgz * && cd ..
```

Then place each `data.tgz` into the correct subdirectory under `Solar2DPlugins`:

```
<Solar2DPlugins path>/com.xedur/plugin.hello/<platform>/data.tgz
```

Only the `data.tgz` files are needed in each directory. Solar2D extracts them during the build process. The raw files (DLLs, Lua files, etc.) should not be placed alongside the tarballs.

### How Solar2D resolves plugins

When your `build.settings` declares a plugin:

```lua
plugins =
{
    ["plugin.hello"] =
    {
        publisherId = "com.xedur",
    },
},
```

Solar2D's build process searches for the plugin in this order:

1. **Custom URL.** Checked if `supportedPlatforms` is provided with URLs (see [Self-Hosted Distribution](#self-hosted-distribution)).
2. **Solar2DPlugins directory.** Looks for `<Solar2DPlugins>/<publisherId>/<plugin name>/<platform>/data.tgz`.
3. **Solar2D Marketplace.** Checked if `marketplaceId` is set.
4. **Solar2D Directory.** The official Solar2D plugin directory.

For local development, option 2 (Solar2DPlugins) is the most practical.

---

## Self-Hosted Distribution

Instead of installing tarballs locally, you can host them on any HTTPS server and reference them in `build.settings`. This is useful for distributing your plugin to other developers without going through the Solar2D Marketplace.

Upload the per-platform `.tgz` files from a GitHub Release (or from the `plugin-tarballs` CI artifact) to your server, then add `supportedPlatforms` to `build.settings`:

```lua
settings =
{
    plugins =
    {
        ["plugin.hello"] =
        {
            publisherId = "com.xedur",
            supportedPlatforms =
            {
                ["win32-sim"]  = { url = "https://example.com/plugins/win32-sim.tgz" },
                ["mac-sim"]    = { url = "https://example.com/plugins/mac-sim.tgz" },
                linux          = { url = "https://example.com/plugins/linux.tgz" },
                iphone         = { url = "https://example.com/plugins/iphone.tgz" },
                ["iphone-sim"] = { url = "https://example.com/plugins/iphone-sim.tgz" },
                android        = { url = "https://example.com/plugins/android.tgz" },
                web            = { url = "https://example.com/plugins/web.tgz" },
            },
        },
    },
}
```

When `supportedPlatforms` with URLs is provided, Solar2D downloads the tarball during the build process instead of looking in the local `Solar2DPlugins` directory.

---

## Testing with the Sample Project

The [`sample/`](sample/) directory contains a Solar2D project that exercises the plugin.

1. Build the plugin using any of the methods above.
2. Install the binary into the Simulator plugins directory (see [Installing for the Simulator](#installing-for-the-simulator)).
3. Open the Solar2D Simulator and load `sample/main.lua`.
4. To test app builds (Windows, macOS, HTML5), set up the `Solar2DPlugins` directory as described in [Installing for App Builds](#installing-for-app-builds).

# Building and Installing

## Table of Contents

- [Overview](#overview)
- [Configuring the Plugin](#configuring-the-plugin)
- [Naming Convention](#naming-convention)
- [Local Build (Windows)](#local-build-windows)
- [CI Builds (GitHub Actions)](#ci-builds-github-actions)
- [Installing for the Simulator](#installing-for-the-simulator)
- [Installing for App Builds](#installing-for-app-builds)
- [Self-Hosted Distribution](#self-hosted-distribution)
- [Testing with the Sample Project](#testing-with-the-sample-project)

## Overview

A Solar2D native plugin is a library that exposes a `luaopen_<module>` function. On desktop platforms and Android it is a shared library (`.dll`, `.dylib`, or `.so`) loaded at runtime; on iOS and tvOS it is a static library (`.a`) linked into the app. When Lua calls `require("plugin.hello")`, Solar2D calls `luaopen_plugin_hello()`, which registers the plugin's functions.

There are two contexts where Solar2D needs to find your plugin:

1. **The Simulator.** When you press "play" in the Solar2D Simulator, it loads plugin binaries from a platform-specific plugins directory on your machine.

2. **App builds.** When you build your app for distribution (e.g. "File > Build > Windows"), Solar2D's build process looks for plugins in the `Solar2DPlugins` directory, packaged as `data.tgz` tarballs. This is a separate mechanism from the Simulator.

You need to set up both if you want to test in the Simulator and also build standalone apps.

The build strategy is split by platform:

- **Windows** is the only local build, via [`local_build.bat`](local_build.bat) in the project root. It builds the plugin DLL and installs it for both the Simulator and Windows app builds. See [Local Build (Windows)](#local-build-windows).
- **Every other platform** (macOS, Linux, iOS, tvOS, Android) is built by [GitHub Actions](#ci-builds-github-actions), which is the source of all release binaries. This repository has no local build script for them, and each needs its own OS and SDKs, so no single machine builds every target.

Every native build goes through the one [`CMakeLists.txt`](CMakeLists.txt), so its source list is the only place to add a new source file. The project enables C only. To add a C++ or Objective-C file, also add its language to the `project()` line, for example `project(${PLUGIN_TARGET} C CXX)`; CMake leaves a file in a language that is not enabled out of the build without an error.

Building produces a binary for each platform:

| Platform | Output File |
| --- | --- |
| Windows | `plugin_hello.dll` |
| macOS | `plugin_hello.dylib` (universal) |
| Linux | `plugin_hello.so` |
| iOS | `libplugin_hello.a` (static library, device and simulator) |
| tvOS | `libplugin_hello.a` (static library, device and simulator) |
| Android | `libplugin_hello.so` (per ABI) |

The HTML5 platform uses a pure JavaScript file (`web/plugin_hello.js`) instead of a compiled binary, so no build step is needed for it.

The `lua/` directory contains a Lua stub (`plugin_hello.lua`) that acts as a fallback on platforms where the native plugin is not available. It returns a valid module with a stub `getGreeting()` function. No build step is needed for this either.

## Configuring the Plugin

The plugin's identity is set in one file, [`metadata.json`](metadata.json):

```json
{
    "publisherId": "com.example",
    "pluginName": "plugin.hello",
    "pluginVersion": "1.0.0",
    "solar2dBuild": "2025.3726",
    "platforms": ["windows", "macos", "linux", "ios", "tvos", "android"],
    "url": "https://example.com/plugin-hello"
}
```

| Field | Meaning |
|-------|---------|
| `publisherId` | Reverse-domain publisher id. Must match the `publisherId` in your `build.settings`. The default `com.example` is a placeholder; set your own before you distribute a plugin. |
| `pluginName` | The Lua module name, e.g. `plugin.hello`. The binary name and the `luaopen_` entry point are derived from it by replacing dots with underscores (`plugin_hello`). |
| `pluginVersion` | Your plugin's own version. Used as the GitHub Release tag (`v1.0.0`). |
| `solar2dBuild` | The minimum Solar2D build number your binaries target. Used as the distribution version directory and the release asset prefix. See [Updating the Plugin Version](#updating-the-plugin-version). |
| `platforms` | Which native builds the CI workflow runs: any of `windows`, `macos`, `linux`, `ios`, `tvos`, `android`. Remove a platform your plugin does not support and its build job is skipped. The `web` and `lua` packages are made regardless. |
| `url` | Your plugin's home page or repository. The default is a placeholder. |

To turn this repo into your own plugin, edit `metadata.json`; the build files need no edits. Every build path reads it: CMake via `string(JSON ...)`, the CI workflow and the iOS, tvOS, and Android build scripts via `tools/read_metadata.sh`, and `local_build.bat` via PowerShell.

The packaging steps also rewrite the plugin name and `publisherId` inside the `lua/` and `web/` files, so those files need no edits after a rename in `metadata.json`. The name to replace is taken from the fallback file's own name (`lua/plugin_hello.lua` gives `plugin_hello` and `plugin.hello`), and the publisher id replaced is `com.example`. An identifier that continues the name with an underscore (`plugin_hello_state`) is renamed with it. For that to work, `lua/` must hold `metadata.lua` plus exactly one other Lua file, and `web/` a `.js` file with the same base name.

`tools/read_metadata.sh` validates the fields and fails the build on bad values:

- `pluginName` must be `plugin.` followed by one identifier of letters, digits, and underscores that starts with a letter. Hyphens and further dots are not allowed: the `luaopen_` entry point must be a valid C identifier, and the packaging steps rebuild the dotted name from the first underscore of the file name.
- `publisherId` must be dot-separated segments of letters, digits, and underscores. Hyphens are not allowed, because the [plugin directory](PUBLISHING.md) splits your release repository name on its first hyphen.
- `solar2dBuild` must be a build number in `YYYY.NNNN` form.
- `platforms` must be a non-empty list of the tokens above, each at most once.

The sample project declares the plugin by its default identity; if you rename the plugin, also update `sample/build.settings` and `sample/main.lua`.

## Naming Convention

Solar2D plugins follow a specific naming convention. The Lua module name uses dots (`plugin.hello`) but the binary filename uses underscores (`plugin_hello.dll`). This matches how Lua's `require` resolves C module names: `require("plugin.hello")` looks for `luaopen_plugin_hello`. On Windows, on macOS, and in every Simulator, Solar2D retries a failed `plugin.*` require with the dots replaced by underscores, which is how a file named `plugin_hello.dll` (or `.dylib`/`.so`) is found.

The conversion is automatic. The build derives the binary name and the `luaopen_` entry point from `pluginName` in [`metadata.json`](metadata.json), so you do not edit `CMakeLists.txt` or the build scripts when you rename the plugin.

Android and Linux apps have no such retry: they look the library up by the exact `require` name, dots included. The packaging step therefore ships those two binaries as `libplugin.hello.so` (Android) and `plugin.hello.so` (Linux). The `luaopen_plugin_hello` function inside them is unchanged. The same rule puts the Lua fallback at `plugin/hello.lua` inside its package. See [Manual setup from local builds](#manual-setup-from-local-builds) for the full layouts.

## Local Build (Windows)

The only local build is on Windows:

```cmd
local_build.bat
```

What it does:

1. Reads the plugin name and publisher from `metadata.json`.
2. Finds Visual Studio through `vswhere` and initialises its MSVC x86 environment via `vcvarsall`. It picks the newest installation that has the C++ tools.
3. Picks a CMake. One already on your PATH is used when it can generate for that Visual Studio (3.21 or newer, or 4.2 or newer for Visual Studio 2026). Otherwise the script offers to download a pinned, SHA-256-verified portable copy (CMake 4.4.3) into `.tools/`, used only for this build and not installed system-wide.
4. Generates the Lua 5.1 import library from `external/lua51/lua51.def`. Solar2D's Windows runtime ships its Lua as `lua.dll`, which is what the `.def` file targets.
5. Builds the plugin DLL (x86) with CMake into `build-win32/`. Solar2D's Windows Simulator and Windows apps are 32-bit, so the plugin must be too.
6. Copies the DLL to the Simulator plugins directory (`%APPDATA%\Corona Labs\Corona Simulator\Plugins`), when Solar2D is installed.
7. Packages and installs `data.tgz` plugins under `%APPDATA%\Solar2DPlugins\com.example\plugin.hello\` for the `win32` (Windows app build), `win32-sim` (Simulator), and `lua` (fallback stub) platforms, so Windows app builds resolve the plugin too.

Prerequisites: Visual Studio 2019, 2022, or 2026 with the "Desktop development with C++" workload. The script also needs `curl` and `tar` on the PATH; both ship with current Windows. The build log is written to `build-win32\build.log`.

Close the Simulator before running the script. A plugin DLL the Simulator has loaded cannot be overwritten, so step 6 fails and the script ends with the warning `plugin install copy failed - close the Corona Simulator and re-run.`

To build manually instead, from a Developer Command Prompt at the project root:

```cmd
lib /def:external\lua51\lua51.def /out:external\lua51\lua51.lib /machine:x86
cmake -B build-win32 -A Win32 -DLUA_LIBRARY="%CD%\external\lua51\lua51.lib"
cmake --build build-win32 --config Release
```

Output: `build-win32\Release\plugin_hello.dll`

CMake 3.19+ is required (the build reads `metadata.json` via `string(JSON ...)`, which was added in CMake 3.19). Generating for Visual Studio 2022 needs CMake 3.21 or newer, and for Visual Studio 2026 CMake 4.2 or newer. The CMake options are `LUA_INCLUDE_DIR` (path to Lua 5.1 headers; defaults to the bundled `external/lua51/`) and `LUA_LIBRARY` (the Lua import library to link, Windows only).

## CI Builds (GitHub Actions)

The workflow at `.github/workflows/build.yml` builds the platforms listed under `platforms` in `metadata.json` and packages the plugin distribution. It runs manually via `workflow_dispatch`; nothing is triggered by a push. There are no inputs: a `config` job reads and validates `metadata.json` through `tools/read_metadata.sh` and feeds the plugin name, publisher, version, Solar2D build, and platform list to every other job. A run started while another is still going waits for it to finish, and starting one more replaces the run that was waiting.

### What it does

1. **Windows.** Generates a Lua import library from the bundled `.def` file, then builds `plugin_hello.dll` via CMake (x86).
2. **macOS.** Builds separately for x86_64 (deployment target macOS 10.13) and arm64 (macOS 11.0) via CMake, then combines them into a universal binary with `lipo`.
3. **Linux.** Builds `plugin_hello.so` via CMake inside an Ubuntu 20.04 container, so the library needs nothing newer than glibc 2.31 and loads on distributions as old as that one. That container's CMake is older than the 3.19 this project needs, so `tools/pin_cmake.sh` installs a pinned, SHA-256-verified CMake 4.4.3 first.
4. **iOS.** Runs `tools/build_apple.sh ios`: `libplugin_hello.a` static libraries via CMake for device (arm64) and Simulator (arm64 + x86_64), deployment target iOS 15.0.
5. **tvOS.** Runs `tools/build_apple.sh tvos`: the same two static libraries for Apple TV, deployment target tvOS 15.0.
6. **Android.** Runs `tools/build_android.sh`: `libplugin_hello.so` for all ABIs (armeabi-v7a, arm64-v8a, x86, x86_64) at API level 21, using the CMake toolchain of the Android NDK, which is preinstalled on the GitHub runners. The libraries are linked with `-Wl,-z,max-page-size=16384` so they are 16 KB page-aligned: Android 15+ runs on devices with 16 KB memory pages and rejects 4 KB-aligned libraries, and only NDK r28+ aligns by default.
7. **Test.** Runs `test/ci_test.sh` on Linux: it builds the plugin for the runner, loads the library in stock Lua 5.1 through `require( "plugin.hello" )`, and checks what `getGreeting()` returns. The apt packages listed in `test/ci_apt.txt` are installed first. The job is skipped when the repository has no `test/ci_test.sh`.
8. **Package.** Runs only when every build job and the test job passed. Assembles the plugin distribution:
   - Copies the compiled binaries from steps 1-6 into the layout each platform's app build expects (see [Manual setup from local builds](#manual-setup-from-local-builds)).
   - Copies the HTML5 JavaScript plugin from `web/plugin_hello.js` and its `web/metadata.lua`.
   - Copies the Lua fallback stub from `lua/plugin_hello.lua` and its `lua/metadata.lua`.
   - Generates a `metadata.lua` for each native platform.
   - Creates per-platform `data.tgz` tarballs for self-hosted distribution.

The iOS and tvOS libraries get one extra step. An app links every plugin's static library into the same executable, so two plugins that both define a global function called `helper` would collide. `tools/merge_static_libs.sh` prelinks each library so that `luaopen_plugin_hello` is its only global symbol, and fails the build if any other one is left.

Every build job ends by checking what it built, and a failed check stops the run before anything is packaged:

- Every platform: the exported `luaopen_plugin_hello` symbol.
- macOS, iOS, tvOS: the expected architectures and the minimum OS version stamped into the binary.
- macOS: the library links only libraries that macOS itself ships.
- Linux: no glibc, libstdc++, or C++ ABI symbol version newer than Ubuntu 20.04 provides (glibc 2.31), and no linked library beyond the C/C++ runtime and X11.
- Android: every LOAD segment is 16 KB-aligned, and the library does not depend on `libc++_shared.so`.

The Apple jobs run on the `macos-15` runner. Its default Xcode 16.4 still accepts macOS 10.13 as a deployment target, while Xcode 26 starts at macOS 11 ([Xcode support matrix](https://developer.apple.com/support/xcode/)).

The same scripts run outside CI on a matching machine, with CMake 3.19+ and `python3` installed: `bash tools/build_apple.sh <ios|tvos> [output dir]` on macOS with Xcode, `bash tools/build_android.sh [output dir]` with `ANDROID_NDK_HOME` set, and `cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release` for the desktop library. `bash test/ci_test.sh` runs the test on Linux with `lua5.1` installed.

CMake 4.4.3 is pinned in two files, each with its own download hash: `local_build.bat` and `tools/pin_cmake.sh`. Update both when you move to a newer CMake.

### Artifacts

Every successful workflow run produces these downloadable artifacts:

| Artifact | Contents |
|----------|----------|
| `win32-sim` | `plugin_hello.dll` |
| `mac-sim` | `plugin_hello.dylib` (universal) |
| `linux` | `plugin_hello.so` |
| `iphone` | `libplugin_hello.a` (device, arm64) |
| `iphone-sim` | `libplugin_hello.a` (simulator, arm64 + x86_64) |
| `appletvos` | `libplugin_hello.a` (device, arm64) |
| `appletvsimulator` | `libplugin_hello.a` (simulator, arm64 + x86_64) |
| `android` | `libplugin_hello.so` (all ABIs) |
| `plugin-distribution` | The unpacked `<solar2dBuild>/<platform>/` tree with the files of every packaged platform |
| `plugin-tarballs` | Ready-to-install `data.tgz` tarballs in `<publisherId>/<plugin.name>/<platform>/` structure (here, `com.example/plugin.hello/`) |

The `plugin-tarballs` artifact is the most useful one for app builds. Extract it and copy the `com.example` folder directly into your `Solar2DPlugins` directory. See [Installing for App Builds](#installing-for-app-builds) for details.

### Releases

Each manual run creates or updates a GitHub Release tagged `v<pluginVersion>` (read from `metadata.json`) and attaches the per-platform tarballs, named `<solar2dBuild>-<platform>.tgz`. A new tag is created on the commit the run built. This asset naming is what the Solar2D Free Plugin Directory expects of a release; see [PUBLISHING.md](PUBLISHING.md).

To cut a release, bump `pluginVersion` in `metadata.json` and run the workflow.

Re-running the workflow with the same `pluginVersion` replaces the tarballs of that release that have the same names, and nothing else: the tag stays on the commit it was first created on, and a tarball from the earlier run that the new run does not produce (after removing a platform or changing `solar2dBuild`) stays attached. Bump `pluginVersion` whenever the code, the platform list, or `solar2dBuild` changes.

### Updating the Plugin Version

`metadata.json` holds two separate versions, and they are not the same thing:

- `pluginVersion` is your plugin's own version (e.g. `1.0.0`). It becomes the GitHub Release tag.
- `solar2dBuild` is the minimum Solar2D build number your binaries target (e.g. `2025.3726`). It is the version directory in the distribution structure and the prefix of each release tarball.

Bump `solar2dBuild` when you rebuild against a newer Solar2D release; bump `pluginVersion` when you ship a new version of your plugin.

## Installing for the Simulator

The Solar2D Simulator loads plugins at runtime from a platform-specific directory. Copy the built binary there:

| Platform | Destination |
| --- | --- |
| Windows | `%APPDATA%\Corona Labs\Corona Simulator\Plugins\plugin_hello.dll` |
| macOS | `~/Library/Application Support/Corona/Simulator/Plugins/plugin_hello.dylib` |
| Linux | `~/.Solar2D/Plugins/plugin_hello.so` |

On Windows, `local_build.bat` does this automatically. On macOS and Linux, download the platform's artifact from a GitHub Actions run and copy the binary manually.

This is sufficient for testing your plugin in the Simulator. However, when you build your app for distribution (e.g. "File > Build > Windows"), the Simulator plugins directory is **not** used. You need to set up the `Solar2DPlugins` directory for that, as described in the next section.

## Installing for App Builds

When Solar2D builds your app for a target platform (Windows desktop, macOS, HTML5, etc.), it looks for plugins in the `Solar2DPlugins` directory. Each plugin needs to be packaged as a `data.tgz` tarball inside a platform-specific subdirectory.

On Windows, `local_build.bat` installs the `win32`, `win32-sim`, and `lua` platforms automatically. For every other platform, use the CI tarballs.

### Using the plugin-tarballs artifact (recommended)

Download the `plugin-tarballs` artifact from a GitHub Actions workflow run, extract the zip, and copy the `com.example` folder into your `Solar2DPlugins` directory:

| OS | Solar2DPlugins Path |
|----|---------------------|
| Windows | `%APPDATA%\Solar2DPlugins\` |
| macOS | `~/Solar2DPlugins/` |
| Linux | `~/.Solar2D/` |

The artifact already contains the correct directory structure:

```text
com.example/plugin.hello/
  win32-sim/data.tgz
  win32/data.tgz
  mac-sim/data.tgz
  macos/data.tgz
  linux/data.tgz
  iphone/data.tgz
  iphone-sim/data.tgz
  appletvos/data.tgz
  appletvsimulator/data.tgz
  android/data.tgz
  web/data.tgz
  lua/data.tgz
```

`win32` and `macos` are the app-build counterparts of `win32-sim` and `mac-sim` and hold the same binaries. An app build falls back from `win32` to `win32-sim` and from `macos` to `mac-sim` when the first is missing.

Solar2D also accepts an optional Solar2D build directory between the plugin name and the platform (`com.example/plugin.hello/2025.3726/win32-sim/data.tgz`), and picks the newest such directory that does not exceed the Solar2D build doing the building. The flat layout above is simpler and preferred when you only track one Solar2D build.

### Manual setup from local builds

If you need to create the tarballs yourself, each platform needs a directory with these contents, which become the root of its `data.tgz`:

| Platform | Contents |
|----------|----------|
| `win32-sim`, `win32` | `plugin_hello.dll`, `metadata.lua` |
| `mac-sim`, `macos` | `plugin_hello.dylib`, `metadata.lua` |
| `linux` | `x86-64/plugin.hello.so`, `metadata.lua` |
| `iphone`, `iphone-sim`, `appletvos`, `appletvsimulator` | `libplugin_hello.a`, `metadata.lua` |
| `android` | `jniLibs/<abi>/libplugin.hello.so` for each ABI, `metadata.lua` |
| `web` | `plugin_hello.js`, `metadata.lua` |
| `lua` | `lua_51/plugin/hello.lua`, `lua/lua_51/plugin/hello.lua`, `metadata.lua` |

The `metadata.lua` file tells Solar2D what kind of plugin it is, and always sits at the root of the tarball. Desktop and Android native plugins use `format = "sharedLibrary"`. iOS and tvOS plugins use `format = "staticLibrary"` and must also list the library name in `staticLibs` (without the `lib` prefix, e.g. `staticLibs = { "plugin_hello" }`); without it, the app build never links the static library and `require` fails at runtime. The HTML5 plugin uses `format = "javascript"`; the HTML5 loader resolves the plugin purely by filename (`plugin_hello.js`), so the format string only matters on the packaging side. The Lua stub uses `format = "lua"`. See the `web/metadata.lua` and `lua/metadata.lua` files in this repository for examples.

Three of those layouts are stricter than they look, and a wrong one fails only on the device or in the built app, never in the Simulator:

- **Android.** The `.so` files must sit under `jniLibs/<abi>/`: the Android app build only collects plugin native libraries from `jniLibs/` paths, and bare `<abi>/` directories get mis-collected into a broken armeabi-v7a-only layout. The file must be named after the `require` name with its dot (`libplugin.hello.so`), because that is the file name the app opens.
- **Linux.** A Linux app build copies only two folders out of a plugin tarball: `x86-64/` (binaries) and `lua/lua_51/` (Lua files). A `.so` at the tarball root is ignored. The file is named `plugin.hello.so`, again after the `require` name.
- **Lua fallback.** The stub is stored on its `require` path, `plugin/hello.lua`, because an app build names it inside the app from that path. It is stored twice: under `lua_51/`, which most platforms read, and under `lua/lua_51/`, which Linux reads.

The `android` directory looks like this before tarring:

```text
android/
  metadata.lua
  jniLibs/
    armeabi-v7a/libplugin.hello.so
    arm64-v8a/libplugin.hello.so
    x86/libplugin.hello.so
    x86_64/libplugin.hello.so
```

For each platform directory, create a `data.tgz` tarball containing its files:

```bash
tar -czf data.tgz -C win32-sim .
```

Then place each `data.tgz` into the correct subdirectory under `Solar2DPlugins`:

```text
<Solar2DPlugins path>/com.example/plugin.hello/<platform>/data.tgz
```

Only the `data.tgz` files are needed in each directory. Solar2D extracts them during the build process. The raw files (DLLs, Lua files, etc.) should not be placed alongside the tarballs.

### How Solar2D resolves plugins

When your `build.settings` declares a plugin:

```lua
plugins =
{
    ["plugin.hello"] =
    {
        publisherId = "com.example",
    },
},
```

Solar2D's build process searches for the plugin in this order:

1. **Custom URL.** Checked if `supportedPlatforms` is provided with URLs (see [Self-Hosted Distribution](#self-hosted-distribution)).
2. **Solar2DPlugins directory.** Looks for `<Solar2DPlugins>/<publisherId>/<plugin name>/<platform>/data.tgz`.
3. **Solar2D Plugins Marketplace.** Checked if `marketplaceId` is set.
4. **Solar2D Free Plugin Directory.** To submit your plugin there, see [PUBLISHING.md](PUBLISHING.md).

For local development, option 2 (Solar2DPlugins) is the most practical.

## Self-Hosted Distribution

Instead of installing tarballs locally, you can host them on any HTTPS server and reference them in `build.settings`. This is useful for distributing your plugin to other developers without going through the Solar2D Plugins Marketplace.

Upload the per-platform `.tgz` files from a GitHub Release (or from the `plugin-tarballs` CI artifact) to your server, then add `supportedPlatforms` to `build.settings`. The release tarballs are named `<solar2dBuild>-<platform>.tgz` (e.g. `2025.3726-win32-sim.tgz`):

```lua
settings =
{
    plugins =
    {
        ["plugin.hello"] =
        {
            publisherId = "com.example",
            supportedPlatforms =
            {
                ["win32-sim"] = { url = "https://example.com/plugins/2025.3726-win32-sim.tgz" },
                win32 = { url = "https://example.com/plugins/2025.3726-win32.tgz" },
                ["mac-sim"] = { url = "https://example.com/plugins/2025.3726-mac-sim.tgz" },
                macos = { url = "https://example.com/plugins/2025.3726-macos.tgz" },
                linux = { url = "https://example.com/plugins/2025.3726-linux.tgz" },
                iphone = { url = "https://example.com/plugins/2025.3726-iphone.tgz" },
                ["iphone-sim"] = { url = "https://example.com/plugins/2025.3726-iphone-sim.tgz" },
                appletvos = { url = "https://example.com/plugins/2025.3726-appletvos.tgz" },
                appletvsimulator = { url = "https://example.com/plugins/2025.3726-appletvsimulator.tgz" },
                android = { url = "https://example.com/plugins/2025.3726-android.tgz" },
                web = { url = "https://example.com/plugins/2025.3726-web.tgz" },
            },
        },
    },
}
```

When `supportedPlatforms` with URLs is provided, Solar2D downloads the tarball during the build process instead of looking in the local `Solar2DPlugins` directory.

## Testing with the Sample Project

The [`sample/`](sample/) directory contains a Solar2D project that exercises the plugin.

1. Build the plugin: on Windows, run `local_build.bat` (it also installs the plugin for the Simulator and for Windows app builds); otherwise download binaries from a GitHub Actions run.
2. Install the binary into the Simulator plugins directory (see [Installing for the Simulator](#installing-for-the-simulator)).
3. Open the Solar2D Simulator and load `sample/main.lua`.
4. To test app builds (Windows, macOS, HTML5), set up the `Solar2DPlugins` directory as described in [Installing for App Builds](#installing-for-app-builds). On Windows, `local_build.bat` has already done this for the Windows platforms.

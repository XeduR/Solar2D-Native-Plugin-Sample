# Solar2D Native Build

Project files for building the plugin using the **Solar2D Native SDK**, the official toolchain bundled with Solar2D. Best for local development: builds and copies the plugin directly into the Simulator's plugins directory.

For full build instructions (including CMake and CI), see [BUILDING.md](../BUILDING.md).

## Prerequisites

- Solar2D installed (the installer sets the `CORONA_ROOT` environment variable)
- **Windows**: Visual Studio 2022 (or 2019) with "Desktop development with C++" workload
- **macOS**: Xcode Command Line Tools
- **Linux**: GCC
- **iOS**: Xcode Command Line Tools
- **Android**: Android NDK (`ANDROID_NDK_HOME` environment variable)

## Building

### Windows

**Visual Studio:**
1. Open `win32/Plugin.sln`
2. Select **Release | Win32**
3. Build (Ctrl+Shift+B)

**Command line:**
```cmd
cd win32
build.bat Release
```

Output: `plugin_hello.dll` → `%APPDATA%\Corona Labs\Corona Simulator\Plugins\`

### macOS

```bash
cd mac
./build.sh
```

Builds a universal binary (x86_64 + arm64) and copies it to `~/Library/Application Support/Corona/Simulator/Plugins/`.

### Linux

```bash
cd linux
./build.sh
```

Output: `plugin_hello.so` in the current directory.

### iOS

```bash
cd ios
./build.sh
```

Builds `libplugin_hello.a` static libraries for iOS device (arm64) and iOS Simulator (arm64 + x86_64). Output is in `device/` and `simulator/` subdirectories.

### Android

```bash
cd android
./build.sh
```

Builds `libplugin_hello.so` shared libraries for all Android ABIs. Requires the Android NDK. Output is in per-ABI subdirectories.

## How It Differs from CMake

| Aspect | Solar2D Native | CMake |
|--------|---------------|-------|
| Lua headers | From SDK (`CORONA_ROOT`) | Bundled in `external/lua51/` |
| Linking (Win) | SDK's `lua.lib` | User-provided Lua library |
| Auto-install | Copies to Simulator plugins dir | Manual copy |
| CI/CD | Requires SDK on runner | Standalone |

The plugin source uses only standard Lua 5.1 headers (`lua.h`, `lauxlib.h`, `lualib.h`) and standard C (`<time.h>`), so both approaches produce identical binaries. The SDK include paths also expose Corona-specific headers (like `CoronaLua.h`) for plugins that need them, but this plugin does not use them.

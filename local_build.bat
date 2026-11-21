@echo off
REM Windows build and local plugin install for this plugin. Prerequisites and
REM behavior are documented in BUILDING.md.

REM The script folder is read before delayed expansion is on so a ! in it survives;
REM every later path use is !VAR!, which cmd does not re-parse for & ( ) or !.
setlocal disabledelayedexpansion
set "ROOT=%~dp0"
setlocal enabledelayedexpansion

REM The script folder ends with a backslash; strip it.
set "ROOT=!ROOT:~0,-1!"
set "TOOLS_DIR=!ROOT!\.tools"
set "BUILD_DIR=!ROOT!\build-win32"

REM Set when any install copy fails (e.g. the Simulator holds the DLL locked);
REM reported as a warning at the end instead of failing silently.
set "INSTALL_COPY_FAILED="

REM Set when a data.tgz packaging step fails; reported as a warning at the end.
set "PACKAGE_FAILED="

REM CMake: the pinned portable copy, used when no CMake on PATH can generate for
REM the installed Visual Studio. The Linux CI job pins the same version (tools/pin_cmake.sh).
set "CMAKE_VER=4.4.3"
set "CMAKE_DIRNAME=cmake-%CMAKE_VER%-windows-x86_64"
set "CMAKE_URL=https://cmake.org/files/v4.4/%CMAKE_DIRNAME%.zip"
set "CMAKE_ZIP_SHA256=4d52ebab7193a698651639ed80d8d04fd903358843572cf44c7fd234cb7c26ab"
set "CMAKE_BIN=!TOOLS_DIR!\%CMAKE_DIRNAME%\bin"

if not exist "!BUILD_DIR!" mkdir "!BUILD_DIR!"

set "LOG=!BUILD_DIR!\build.log"
echo Solar2D plugin Windows build started: %date% %time% > "!LOG!" || (
	echo ERROR: cannot write !LOG!
	pause
	exit /b 1
)
echo. >> "!LOG!"

REM Paths and values go to PowerShell via the environment (here and in every later call) to avoid quoting conflicts with for /f.
set "_MD_FILE=!ROOT!\metadata.json"
if not exist "!_MD_FILE!" (
	echo ERROR: metadata.json not found at "!_MD_FILE!". >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)
set "PLUGIN_NAME_DOTTED="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(ConvertFrom-Json -InputObject (Get-Content -Raw -LiteralPath $env:_MD_FILE)).pluginName"`) do set "PLUGIN_NAME_DOTTED=%%I"
set "PUBLISHER_ID="
for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "(ConvertFrom-Json -InputObject (Get-Content -Raw -LiteralPath $env:_MD_FILE)).publisherId"`) do set "PUBLISHER_ID=%%I"
if not defined PLUGIN_NAME_DOTTED (
	echo ERROR: could not read pluginName from metadata.json. >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)
if not defined PUBLISHER_ID (
	echo ERROR: could not read publisherId from metadata.json. >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)
REM Binary and luaopen symbol use the module name with dots as underscores.
set "PLUGIN_NAME=%PLUGIN_NAME_DOTTED:.=_%"

REM Only the one fallback Lua file ships; CI packaging refuses anything else.
set "FALLBACK_SRC="
set /a _LUA_COUNT=0
set "_LUA_LIST="
for %%F in ("!ROOT!\lua\*.lua") do (
	if /i not "%%~nxF"=="metadata.lua" (
		set /a _LUA_COUNT+=1
		set "_LUA_LIST=!_LUA_LIST! %%~nxF"
		set "FALLBACK_SRC=%%~nF"
	)
)
if !_LUA_COUNT! NEQ 1 (
	echo ERROR: !ROOT!\lua must hold metadata.lua plus exactly one fallback Lua file, found !_LUA_COUNT!:!_LUA_LIST! >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)

echo Plugin: %PLUGIN_NAME_DOTTED% (%PLUGIN_NAME%), publisher: %PUBLISHER_ID% >> "!LOG!"
echo Building %PLUGIN_NAME_DOTTED% ...

REM Visual Studio decides the CMake generator, so it is found before CMake.
call :findVisualStudio
if errorlevel 1 (
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)

REM CMake: use the copy on PATH, a previously downloaded portable copy, or fetch.
REM A PATH cmake is used only when it can generate for that Visual Studio.
where cmake >nul 2>&1
if errorlevel 1 goto :cmakeUsePortable
set "CMAKE_PATH_VER="
for /f "tokens=3" %%V in ('cmake --version 2^>nul ^| findstr /b /c:"cmake version"') do if not defined CMAKE_PATH_VER set "CMAKE_PATH_VER=%%V"
set "_CM_MAJOR=0"
set "_CM_MINOR=0"
if defined CMAKE_PATH_VER for /f "tokens=1,2 delims=." %%A in ("!CMAKE_PATH_VER!") do (
	set "_CM_MAJOR=%%A"
	set "_CM_MINOR=%%B"
)
set /a "_CM_MAJOR=_CM_MAJOR" >nul 2>&1 || set "_CM_MAJOR=0"
set /a "_CM_MINOR=_CM_MINOR" >nul 2>&1 || set "_CM_MINOR=0"
set /a "_CM_VALUE=_CM_MAJOR * 100 + _CM_MINOR"
set /a "_CM_NEEDED=CMAKE_MIN_MAJOR * 100 + CMAKE_MIN_MINOR"
if !_CM_VALUE! lss !_CM_NEEDED! goto :cmakePathRejected
goto :cmakeReady

:cmakePathRejected
if defined CMAKE_PATH_VER (
	echo PATH CMake !CMAKE_PATH_VER! cannot generate for !VS_GENERATOR!; need !CMAKE_MIN_MAJOR!.!CMAKE_MIN_MINOR! or newer. Using the pinned portable copy. >> "!LOG!"
) else (
	echo Could not read the PATH CMake version; using the pinned portable copy. >> "!LOG!"
)

:cmakeUsePortable
if exist "!CMAKE_BIN!\cmake.exe" (
	set "PATH=!CMAKE_BIN!;!PATH!"
	echo Using portable CMake at !CMAKE_BIN! >> "!LOG!"
	goto :cmakeReady
)
call :installCmake
if errorlevel 1 (
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)
set "PATH=!CMAKE_BIN!;!PATH!"
:cmakeReady

REM MSVC: if lib/cl are not on PATH, initialise the environment via vcvarsall.
where lib >nul 2>&1
if %errorlevel% equ 0 goto :msvcReady
call :setupMsvc
if errorlevel 1 (
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)
:msvcReady

set "LUA_DEF=!ROOT!\external\lua51\lua51.def"
set "LUA_LIB=!ROOT!\external\lua51\lua51.lib"
echo Generating lua51.lib from .def... >> "!LOG!"
lib /def:"!LUA_DEF!" /out:"!LUA_LIB!" /machine:x86 >> "!LOG!" 2>&1
if !errorlevel! neq 0 (
	echo ERROR: Failed to generate lua51.lib. >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)

REM Disable MSBuild node reuse so cmake --build leaves no lingering msbuild.exe
REM holding the build log open after it returns (same lock class as vcvarsall).
set "MSBUILDDISABLENODEREUSE=1"

REM A fresh build directory gets the generator and instance of the Visual Studio
REM found above; an existing one keeps the generator it was configured with.
set "CMAKE_GENERATOR_ARGS="
if not exist "!BUILD_DIR!\CMakeCache.txt" set "CMAKE_GENERATOR_ARGS=-G "!VS_GENERATOR!" -DCMAKE_GENERATOR_INSTANCE="!VS_INSTANCE!""

REM The success gate below must only see a DLL this run produced; a locked leftover would pass it.
del /q "!BUILD_DIR!\Release\%PLUGIN_NAME%.dll" 2>nul
if exist "!BUILD_DIR!\Release\%PLUGIN_NAME%.dll" (
	echo ERROR: cannot delete the previous %PLUGIN_NAME%.dll; another process holds it open. >> "!LOG!"
	echo Build failed: previous %PLUGIN_NAME%.dll is locked by another process. Close it and re-run.
	pause
	exit /b 1
)

echo Configuring CMake... >> "!LOG!"
echo. >> "!LOG!"
cmake -B "!BUILD_DIR!" -S "!ROOT!" !CMAKE_GENERATOR_ARGS! -A Win32 -DLUA_LIBRARY="!LUA_LIB!" >> "!LOG!" 2>&1
if %errorlevel% neq 0 (
	echo. >> "!LOG!"
	echo ERROR: CMake configure failed. >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)

echo. >> "!LOG!"
echo Building... >> "!LOG!"
echo. >> "!LOG!"
cmake --build "!BUILD_DIR!" --config Release --target %PLUGIN_NAME% >> "!LOG!" 2>&1
if %errorlevel% neq 0 (
	echo. >> "!LOG!"
	echo ERROR: Build failed. >> "!LOG!"
	echo Build failed. See !LOG! for details.
	pause
	exit /b 1
)

REM A failed output redirect prints an error but does not set errorlevel, so the
REM checks above can pass without anything being built. Confirm the DLL exists.
if not exist "!BUILD_DIR!\Release\%PLUGIN_NAME%.dll" (
	echo ERROR: build reported success but %PLUGIN_NAME%.dll was not produced. >> "!LOG!"
	echo Build failed: output DLL not found. See !LOG! for details.
	pause
	exit /b 1
)

echo. >> "!LOG!"
echo Built: !BUILD_DIR!\Release\%PLUGIN_NAME%.dll >> "!LOG!"

set "SIM_DIR=!APPDATA!\Corona Labs\Corona Simulator"
set "PLUGINS_DIR=!SIM_DIR!\Plugins"
if exist "!SIM_DIR!" (
	if not exist "!PLUGINS_DIR!" mkdir "!PLUGINS_DIR!"
	copy /y "!BUILD_DIR!\Release\%PLUGIN_NAME%.dll" "!PLUGINS_DIR!\" >> "!LOG!" 2>&1 || set "INSTALL_COPY_FAILED=1"
	echo Installed to: !PLUGINS_DIR! >> "!LOG!"
)

REM win32 (app builds) and win32-sim (Simulator) share the same x86 DLL; lua
REM is the fallback stub for platforms without a native binary.
call :installNativePlugin win32
call :installNativePlugin win32-sim
call :installLuaStub

echo. >> "!LOG!"
echo Build completed: %date% %time% >> "!LOG!"
if defined INSTALL_COPY_FAILED (
	echo WARNING: plugin install copy failed - close the Corona Simulator and re-run. >> "!LOG!"
	echo WARNING: plugin install copy failed - close the Corona Simulator and re-run.
)
if defined PACKAGE_FAILED (
	echo WARNING: could not create one or more plugin data.tgz packages - see the log for details. >> "!LOG!"
	echo WARNING: could not create one or more plugin data.tgz packages - see the log for details.
)
echo Build succeeded. See !LOG! for details.
pause
exit /b 0

REM Package the build as a local plugin data.tgz under
REM APPDATA\Solar2DPlugins\<publisherId>\<pluginName>\%1.

:installNativePlugin
set "STAGE=!BUILD_DIR!\pkg\%~1"
if exist "!STAGE!" rmdir /s /q "!STAGE!"
mkdir "!STAGE!"
copy /y "!BUILD_DIR!\Release\%PLUGIN_NAME%.dll" "!STAGE!\" >> "!LOG!" 2>&1
(
	echo local metadata = {
	echo plugin = {
	echo format = "sharedLibrary",
	echo },
	echo }
	echo return metadata
) > "!STAGE!\metadata.lua"
set "DEST=!APPDATA!\Solar2DPlugins\%PUBLISHER_ID%\%PLUGIN_NAME_DOTTED%\%~1"
if not exist "!DEST!" mkdir "!DEST!"
"%SystemRoot%\System32\tar.exe" -czf "!DEST!\data.tgz" -C "!STAGE!" . >> "!LOG!" 2>&1
if errorlevel 1 (
	echo WARNING: could not create !DEST!\data.tgz; tar is required ^(Win10 1803+^). >> "!LOG!"
	set "PACKAGE_FAILED=1"
) else (
	echo Installed plugin: !DEST!\data.tgz >> "!LOG!"
)
exit /b 0

REM Install the Lua fallback stub, rewritten from the committed identity to the
REM metadata identity with the same replacements the CI packaging step applies.

:installLuaStub
set "STAGE=!BUILD_DIR!\pkg\lua"
if exist "!STAGE!" rmdir /s /q "!STAGE!"
mkdir "!STAGE!"
set "_TPL_SRC=!ROOT!\lua\%FALLBACK_SRC%.lua"
set "_SRC_NAME=%FALLBACK_SRC%"
REM The dotted name assumes the plugin.<name> convention: the first underscore becomes the dot.
for /f "tokens=1* delims=_" %%A in ("!_SRC_NAME!") do (
	if "%%B"=="" (set "_SRC_DOTTED=%%A") else (set "_SRC_DOTTED=%%A.%%B")
)
REM The lua fallback ships nested on its require path, under both lua_51 and
REM lua/lua_51, to match CI: platform collectors merge the payload root up while
REM Linux reads only lua/lua_51.
set "_LS_NAMEPATH=%PLUGIN_NAME_DOTTED:.=\%"
set "_TPL_DST=!STAGE!\lua_51\%_LS_NAMEPATH%.lua"
set "_TPL_DST_NESTED=!STAGE!\lua\lua_51\%_LS_NAMEPATH%.lua"
powershell -NoProfile -Command "$t = Get-Content -Raw -LiteralPath $env:_TPL_SRC; $t = [regex]::Replace($t, '\b' + [regex]::Escape($env:_SRC_DOTTED) + '(\b|_)', $env:PLUGIN_NAME_DOTTED + '$1'); $t = [regex]::Replace($t, '\b' + [regex]::Escape($env:_SRC_NAME) + '(\b|_)', $env:PLUGIN_NAME + '$1'); $t = [regex]::Replace($t, '\bcom\.xedur\b', $env:PUBLISHER_ID); [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($env:_TPL_DST)); [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($env:_TPL_DST_NESTED)); Set-Content -NoNewline -LiteralPath $env:_TPL_DST -Value $t" >> "!LOG!" 2>&1
if not exist "!_TPL_DST!" (
	echo WARNING: could not generate the lua stub at !_TPL_DST!. >> "!LOG!"
	set "PACKAGE_FAILED=1"
	exit /b 0
)
copy /y "!_TPL_DST!" "!_TPL_DST_NESTED!" >> "!LOG!" 2>&1
copy /y "!ROOT!\lua\metadata.lua" "!STAGE!\" >> "!LOG!" 2>&1
set "DEST=!APPDATA!\Solar2DPlugins\%PUBLISHER_ID%\%PLUGIN_NAME_DOTTED%\lua"
if not exist "!DEST!" mkdir "!DEST!"
"%SystemRoot%\System32\tar.exe" -czf "!DEST!\data.tgz" -C "!STAGE!" . >> "!LOG!" 2>&1
if errorlevel 1 (
	echo WARNING: could not create !DEST!\data.tgz; tar is required. >> "!LOG!"
	set "PACKAGE_FAILED=1"
) else (
	echo Installed plugin: !DEST!\data.tgz >> "!LOG!"
)
exit /b 0

REM Prompt for and install the pinned portable CMake into TOOLS_DIR.

:installCmake
echo.
echo No CMake that can generate for !VS_GENERATOR! was found on your PATH.
echo This script can download a pinned portable copy of CMake %CMAKE_VER% from the
echo official Kitware server and use it for this build only. It is stored under
echo !TOOLS_DIR! and is not installed system-wide.
echo.
set "REPLY="
set /p "REPLY=Download CMake %CMAKE_VER% now? [Y/n] "
if /i "%REPLY%"=="n" (
	echo CMake download declined by user. >> "!LOG!"
	echo Install CMake !CMAKE_MIN_MAJOR!.!CMAKE_MIN_MINOR! or newer on your PATH, then re-run this script.
	exit /b 1
)
if not exist "!TOOLS_DIR!" mkdir "!TOOLS_DIR!"
echo Downloading CMake %CMAKE_VER% ...
call :fetchVerifiedZip "%CMAKE_URL%" "%CMAKE_ZIP_SHA256%" "%CMAKE_DIRNAME%"
if errorlevel 1 exit /b 1
if not exist "!CMAKE_BIN!\cmake.exe" (
	echo ERROR: cmake.exe missing after extraction at !CMAKE_BIN! >> "!LOG!"
	exit /b 1
)
echo Portable CMake %CMAKE_VER% ready at !CMAKE_BIN! >> "!LOG!"
exit /b 0

REM Find the newest Visual Studio with the C++ build tools; a newer instance
REM without them must not hide an older one that has them. Sets VS_PATH,
REM VS_INSTANCE, VS_GENERATOR, and the oldest CMake that generates for it.

:findVisualStudio
echo Locating Visual Studio via vswhere ... >> "!LOG!"
set "VSWHERE_DIR=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"
if not exist "%VSWHERE_DIR%\vswhere.exe" (
	echo ERROR: vswhere.exe not found in "!VSWHERE_DIR!". >> "!LOG!"
	echo Install Visual Studio 2019 or newer with the "Desktop development with C++" workload.
	exit /b 1
)
REM Run vswhere by full path. for /f's cmd /c strips the first and last quote of a
REM line that starts with one, so the command carries an extra outer pair.
set "VS_PATH="
set "VS_VERSION="
for /f "usebackq tokens=*" %%I in (`""!VSWHERE_DIR!\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath"`) do set "VS_PATH=%%I"
for /f "usebackq tokens=*" %%I in (`""!VSWHERE_DIR!\vswhere.exe" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationVersion"`) do set "VS_VERSION=%%I"
if not defined VS_PATH (
	echo ERROR: no Visual Studio with the C++ build tools was found. >> "!LOG!"
	echo Install Visual Studio 2019 or newer with the "Desktop development with C++" workload.
	exit /b 1
)

set "VS_MAJOR="
for /f "tokens=1 delims=." %%V in ("!VS_VERSION!") do set "VS_MAJOR=%%V"
set "VS_GENERATOR="
if "!VS_MAJOR!"=="16" set "VS_GENERATOR=Visual Studio 16 2019"
if "!VS_MAJOR!"=="17" set "VS_GENERATOR=Visual Studio 17 2022"
if "!VS_MAJOR!"=="18" set "VS_GENERATOR=Visual Studio 18 2026"
if not defined VS_GENERATOR (
	echo ERROR: Visual Studio !VS_VERSION! at "!VS_PATH!" is not one of 2019, 2022, or 2026. >> "!LOG!"
	echo Install Visual Studio 2019, 2022, or 2026 with the "Desktop development with C++" workload.
	exit /b 1
)

REM The Visual Studio 17 2022 generator needs CMake 3.21, Visual Studio 18 2026 needs 4.2.
set "CMAKE_MIN_MAJOR=3"
set "CMAKE_MIN_MINOR=21"
if "!VS_MAJOR!"=="18" (
	set "CMAKE_MIN_MAJOR=4"
	set "CMAKE_MIN_MINOR=2"
)

REM CMake records generator instances with forward slashes.
set "VS_INSTANCE=!VS_PATH:\=/!"
echo Using !VS_GENERATOR! at "!VS_PATH!" >> "!LOG!"
exit /b 0

REM Initialise the MSVC x86 environment of the Visual Studio found above.

:setupMsvc
echo Setting up the MSVC build environment ...
set "VCVARSALL=!VS_PATH!\VC\Auxiliary\Build\vcvarsall.bat"
if not exist "!VCVARSALL!" (
	echo ERROR: vcvarsall.bat not found under "!VS_PATH!". >> "!LOG!"
	exit /b 1
)
echo Initialising MSVC x86 environment from "!VCVARSALL!" >> "!LOG!"
REM vcvarsall output goes to NUL, not the log: its helper processes inherit the
REM redirected handle and would keep build.log locked for the rest of the script.
call "!VCVARSALL!" x86 >nul 2>&1
if errorlevel 1 (
	echo ERROR: vcvarsall.bat failed. >> "!LOG!"
	exit /b 1
)
where lib >nul 2>&1
if errorlevel 1 (
	echo ERROR: 'lib' still not on PATH after running vcvarsall. >> "!LOG!"
	exit /b 1
)
echo MSVC environment ready. >> "!LOG!"
exit /b 0

REM Download %1, verify its SHA-256 equals %2, and install it as TOOLS_DIR\%3. The zip's
REM top-level %3 folder is extracted under %3.partial and renamed in only on success.

:fetchVerifiedZip
set "_FVZ_URL=%~1"
set "_FVZ_SHA=%~2"
set "_FVZ_NAME=%~3"
set "_FVZ_ZIP=!TOOLS_DIR!\%~3.zip"
set "_FVZ_DEST=!TOOLS_DIR!\%~3"

where curl >nul 2>&1
if errorlevel 1 (
	echo ERROR: curl.exe not found; needs Windows 10 1803 or newer. >> "!LOG!"
	exit /b 1
)

echo Downloading !_FVZ_URL! >> "!LOG!"
curl -fL -o "!_FVZ_ZIP!" "!_FVZ_URL!" >> "!LOG!" 2>&1
if errorlevel 1 (
	echo ERROR: download failed; check your internet connection. >> "!LOG!"
	exit /b 1
)

set "_FVZ_ACTUAL="
for /f %%H in ('powershell -NoProfile -Command "(Get-FileHash -Algorithm SHA256 -LiteralPath $env:_FVZ_ZIP).Hash"') do set "_FVZ_ACTUAL=%%H"
if /i not "!_FVZ_ACTUAL!"=="!_FVZ_SHA!" (
	echo ERROR: checksum mismatch for "!_FVZ_ZIP!". >> "!LOG!"
	echo   expected: !_FVZ_SHA! >> "!LOG!"
	echo   actual:   !_FVZ_ACTUAL! >> "!LOG!"
	del /q "!_FVZ_ZIP!"
	exit /b 1
)
echo Checksum verified for "!_FVZ_ZIP!". >> "!LOG!"

powershell -NoProfile -Command "$ErrorActionPreference = 'Stop'; $tmp = $env:_FVZ_DEST + '.partial'; if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }; Expand-Archive -LiteralPath $env:_FVZ_ZIP -DestinationPath $tmp; if (Test-Path -LiteralPath $env:_FVZ_DEST) { Remove-Item -LiteralPath $env:_FVZ_DEST -Recurse -Force }; [IO.Directory]::Move([IO.Path]::Combine($tmp, $env:_FVZ_NAME), $env:_FVZ_DEST); if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }" >> "!LOG!" 2>&1
if errorlevel 1 (
	echo ERROR: extraction failed for "!_FVZ_ZIP!". >> "!LOG!"
	exit /b 1
)
del /q "!_FVZ_ZIP!"
exit /b 0

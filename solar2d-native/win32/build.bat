@echo off
REM Solar2D Hello Plugin - Windows Build Script
REM
REM Builds plugin_hello.dll using the Solar2D Native SDK.
REM
REM Prerequisites:
REM   - Visual Studio 2022 (or 2019) with C++ desktop workload
REM   - Solar2D Native SDK installed (CORONA_ROOT environment variable)
REM
REM Usage:
REM   build.bat [Release|Debug]
REM

setlocal

set CONFIG=%1
if "%CONFIG%"=="" set CONFIG=Release

set SCRIPT_DIR=%~dp0

REM Check for CORONA_ROOT
if not defined CORONA_ROOT (
    echo ERROR: CORONA_ROOT environment variable is not set.
    echo Please install Solar2D and set CORONA_ROOT to the Native SDK path.
    echo Example: set CORONA_ROOT=C:\Program Files ^(x86^)\Corona Labs\Corona\Native
    exit /b 1
)

echo Building Solar2D Hello Plugin (%CONFIG%)...
echo   CORONA_ROOT: %CORONA_ROOT%

REM Try to find MSBuild
set MSBUILD=
for /f "delims=" %%i in ('"%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe 2^>nul') do set MSBUILD=%%i

if not exist "%MSBUILD%" (
    echo ERROR: MSBuild not found. Please install Visual Studio with C++ desktop workload.
    exit /b 1
)

echo   MSBuild: %MSBUILD%

"%MSBUILD%" "%SCRIPT_DIR%Plugin.sln" /p:Configuration=%CONFIG% /p:Platform=Win32 /m
if %ERRORLEVEL% neq 0 (
    echo Build failed!
    exit /b %ERRORLEVEL%
)

echo Build succeeded!
echo Output: %SCRIPT_DIR%%CONFIG%\plugin_hello.dll

REM The post-build step in the .vcxproj copies the DLL to the Simulator plugins directory.
echo Plugin has been installed to the Solar2D Simulator plugins directory.

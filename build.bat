@echo off
setlocal enabledelayedexpansion

:: Configuration
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TARGET_DIR=%AEROSIM_OMNIVERSE_ROOT%\source\extensions"
set "AEROSIM_EXTENSION=aerosim.omniverse.extension"
set "CESIUM_FOLDER1=cesium.omniverse"
set "CESIUM_FOLDER2=cesium.usd.plugins"
set "CESIUM_VERSION=v0.27.0"
set "ZIP_URL=https://github.com/CesiumGS/cesium-omniverse/releases/download/%CESIUM_VERSION%/CesiumGS-cesium-omniverse-windows-x86_64-%CESIUM_VERSION%.zip"
set "ZIP_FILE=%TARGET_DIR%\cesium_omniverse.zip"
set "EXTRACT_PATH=%TARGET_DIR%"

:: Check if both folders exist
if exist "%TARGET_DIR%\%CESIUM_FOLDER1%\" (
    if exist "%TARGET_DIR%\%CESIUM_FOLDER2%\" (
        echo Cesium extension folders already exist. No need to download.
        goto :cesium_done
    )
)

:: Create target directory if it doesn't exist
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"

:: Download the ZIP file if the folders don't exist
echo Downloading Cesium Omniverse %CESIUM_VERSION%...
powershell -Command "(New-Object Net.WebClient).DownloadFile('%ZIP_URL%', '%ZIP_FILE%')"
if %errorlevel% neq 0 (
    echo Error: The file could not be downloaded.
    exit /b 1
)
echo File downloaded successfully.

:: Extract the ZIP file
echo Extracting the file to %EXTRACT_PATH%...
powershell -Command "Expand-Archive -Path '%ZIP_FILE%' -DestinationPath '%EXTRACT_PATH%' -Force"
if %errorlevel% neq 0 (
    echo Error: Extraction failed.
    exit /b 1
)
echo Extraction completed successfully.

:: Check if extraction was successful
if exist "%EXTRACT_PATH%\%CESIUM_FOLDER1%\" (
    echo Extraction verified.
) else (
    echo Error: The folder %CESIUM_FOLDER1% was not found after extraction.
)

echo repo_build.prebuild_link { "mdl", ext.target_dir.."/mdl" } >> "%TARGET_DIR%\%CESIUM_FOLDER1%\premake5.lua"
echo repo_build.prebuild_link { "vendor", ext.target_dir.."/vendor" } >> "%TARGET_DIR%\%CESIUM_FOLDER1%\premake5.lua"

:: Delete the ZIP file after extraction
del "%ZIP_FILE%"
echo ZIP file deleted.

:cesium_done

echo AEROSIM_WORLD_LINK_LIB is set to: %AEROSIM_WORLD_LINK_LIB%
:: Copy aerosim-world-link lib files into the extension directory so they are accessible
:: when Kit builds inside a Docker container (docker build option), where the original
:: AEROSIM_WORLD_LINK_LIB host path may not be mounted. premake5.lua reads the path from
:: aerosim_world_link_lib_path.txt to set includedirs, libdirs, and post-build copy commands.
set "WORLD_LINK_LIB_DIR=%TARGET_DIR%\%AEROSIM_EXTENSION%\aerosim-world-link-lib"
if not exist "%WORLD_LINK_LIB_DIR%" mkdir "%WORLD_LINK_LIB_DIR%"
echo Copying AEROSIM_WORLD_LINK_LIB files to %WORLD_LINK_LIB_DIR%...
xcopy /E /Y /I /Q "%AEROSIM_WORLD_LINK_LIB%\*" "%WORLD_LINK_LIB_DIR%"
if %errorlevel% neq 0 (
    echo ERROR: Failed to copy AEROSIM_WORLD_LINK_LIB files.
    exit /b 1
)
echo %WORLD_LINK_LIB_DIR%>"%TARGET_DIR%\%AEROSIM_EXTENSION%\aerosim_world_link_lib_path.txt"

:: =============================================================================
:: Detect Visual Studio installation (prefer VS2026, fall back to VS2022)
:: Both VS2026 and VS2022 require the VS2019 v142 toolchain to be installed
:: in order to link against the USD dependency Boost libs (built for vc142).
:: =============================================================================

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VS_LABEL="
set "VS_PATH="

if not exist "%VSWHERE%" (
    echo WARNING: vswhere.exe not found. Cannot auto-detect Visual Studio.
    goto :vs_detection_done
)

:: Use vswhere to get the latest VS installation path and major version number.
:: Prefer VS2026 (major=18) over VS2022 (major=17). Version ranges use square
:: brackets which are unreliable in cmd backtick loops, so we read the latest
:: install and check the major version number directly.
set "VS_MAJOR="
for /f "usebackq tokens=1 delims=." %%i in (`"%VSWHERE%" -all -latest -property installationVersion 2^>nul`) do (
    set "VS_MAJOR=%%i"
)
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -all -latest -property installationPath 2^>nul`) do (
    set "VS_PATH=%%i"
)

if "!VS_MAJOR!"=="18" (
    set "VS_LABEL=VS2026"
) else if "!VS_MAJOR!"=="17" (
    set "VS_LABEL=VS2022"
) else if defined VS_MAJOR (
    :: Unknown future version - try it anyway with the same v142 config
    echo WARNING: Unknown VS version !VS_MAJOR!.x detected. Attempting VS2026 config.
    set "VS_LABEL=VS!VS_MAJOR!"
)

if not defined VS_LABEL (
    echo WARNING: Neither VS2026 nor VS2022 found. Build may fail.
    echo          Install Visual Studio 2022 or 2026 with the VS2019 v142 C++ toolchain.
    goto :vs_detection_done
)

echo Detected %VS_LABEL% at: !VS_PATH!

:: Verify the v142 toolchain is installed in this VS
if not exist "!VS_PATH!\VC\Auxiliary\Build\Microsoft.VCToolsVersion.v142.default.txt" (
    echo ERROR: VS2019 v142 toolchain not found in !VS_PATH!
    echo        Install it via Visual Studio Installer ^> Individual components ^>
    echo        "MSVC v142 - VS 2019 C++ x64/x86 build tools"
    exit /b 1
)

:: Bootstrap repo tools (fetches repo_build to _repo\deps\repo_build via packman)
echo Bootstrapping repo tools...
call "%SCRIPT_DIR%\tools\packman\packman.cmd" pull "%SCRIPT_DIR%\deps\repo-deps.packman.xml"
if %errorlevel% neq 0 (
    echo ERROR: Failed to bootstrap repo tools.
    exit /b %errorlevel%
)

:: Apply repo_build patches for VS2022/VS2026 + v142 toolchain compatibility
echo Applying repo_build compatibility patches...
call "%SCRIPT_DIR%\tools\packman\python.bat" "%SCRIPT_DIR%\tools\apply_repobuild_patches.py"
if %errorlevel% neq 0 (
    echo ERROR: Failed to apply repo_build patches.
    exit /b %errorlevel%
)

:: Configure repo.toml [repo_build.msbuild] for detected VS
call "%SCRIPT_DIR%\tools\packman\python.bat" "%SCRIPT_DIR%\tools\configure_vs.py" "!VS_LABEL!" "!VS_PATH!"
if %errorlevel% neq 0 (
    echo ERROR: Failed to configure repo.toml.
    exit /b %errorlevel%
)

:vs_detection_done

call "%SCRIPT_DIR%\repo" build %*

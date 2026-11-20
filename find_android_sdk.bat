@echo off
echo Searching for Android SDK...
echo.

set "SDK_PATH="

REM Check common locations
if exist "%LOCALAPPDATA%\Android\Sdk" (
    echo Found SDK at: %LOCALAPPDATA%\Android\Sdk
    set "SDK_PATH=%LOCALAPPDATA%\Android\Sdk"
) else if exist "%USERPROFILE%\AppData\Local\Android\Sdk" (
    echo Found SDK at: %USERPROFILE%\AppData\Local\Android\Sdk
    set "SDK_PATH=%USERPROFILE%\AppData\Local\Android\Sdk"
) else if exist "C:\Android\Sdk" (
    echo Found SDK at: C:\Android\Sdk
    set "SDK_PATH=C:\Android\Sdk"
) else (
    echo Android SDK not found in common locations.
    echo.
    echo Recommended path for new installation:
    echo %LOCALAPPDATA%\Android\Sdk
)

if defined SDK_PATH (
    echo.
    echo Use this path in Android Studio: %SDK_PATH%
)

echo.
pause







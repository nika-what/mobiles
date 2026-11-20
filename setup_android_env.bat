@echo off
echo Setting up Android SDK environment variables...
echo.

REM Find Android SDK path (common locations)
set "SDK_PATH="

if exist "%LOCALAPPDATA%\Android\Sdk" (
    set "SDK_PATH=%LOCALAPPDATA%\Android\Sdk"
    echo Found SDK at: %SDK_PATH%
) else if exist "%USERPROFILE%\AppData\Local\Android\Sdk" (
    set "SDK_PATH=%USERPROFILE%\AppData\Local\Android\Sdk"
    echo Found SDK at: %SDK_PATH%
) else if exist "C:\Android\Sdk" (
    set "SDK_PATH=C:\Android\Sdk"
    echo Found SDK at: %SDK_PATH%
) else (
    echo Android SDK not found in common locations.
    echo Please install Android Studio first, or enter the SDK path manually.
    echo.
    set /p "SDK_PATH=Enter Android SDK path: "
)

if not exist "%SDK_PATH%" (
    echo Error: SDK path does not exist: %SDK_PATH%
    pause
    exit /b 1
)

echo.
echo Setting environment variables for current session...
setx ANDROID_HOME "%SDK_PATH%"
setx ANDROID_SDK_ROOT "%SDK_PATH%"

REM Add to PATH
echo.
echo Adding to PATH...
for /f "tokens=2*" %%A in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "CURRENT_PATH=%%B"
echo %CURRENT_PATH% | findstr /C:"%SDK_PATH%\platform-tools" >nul
if errorlevel 1 (
    setx PATH "%CURRENT_PATH%;%SDK_PATH%\platform-tools;%SDK_PATH%\tools;%SDK_PATH%\tools\bin"
    echo Added platform-tools and tools to PATH
) else (
    echo PATH already contains Android SDK
)

echo.
echo Environment variables set!
echo.
echo NOTE: You need to restart your terminal/PowerShell for changes to take effect.
echo After restart, verify with: flutter doctor
echo.
pause







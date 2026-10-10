@echo off
REM ============================================================
REM  Flick Flock - local Studio launcher
REM  Run it once from anywhere; it puts an Al-kkagi shortcut on the Desktop.
REM  1. git clone (first time) / git pull (every time)
REM  2. download Rojo + install the Rojo Studio plugin
REM  3. build FlickFlock.rbxlx and open it in Roblox Studio
REM  4. run "rojo serve" so Studio syncs live with the repo
REM ============================================================

REM git pull may rewrite this very file, so run from a temp copy.
if /i not "%~1"=="--from-temp" (
    copy /y "%~f0" "%TEMP%\flickflock_start.bat" >nul
    call "%TEMP%\flickflock_start.bat" --from-temp "%~dp0"
    exit /b
)

setlocal
chcp 65001 >nul
title Flick Flock - Rojo

set "REPO_URL=https://github.com/kimtaenim/roblox-flick-flock.git"
set "BRANCH=main"
set "PORT=34872"
set "ROJO_VERSION=7.4.4"
set "PLACE=FlickFlock.rbxlx"
set "ROBLOX_ACCOUNT=oompaloompa0730"

REM Use the folder this .bat lives in if it is the repo,
REM otherwise clone into %USERPROFILE%\roblox-flick-flock.
set "HERE=%~2"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
if exist "%HERE%\.git" (
    set "REPO=%HERE%"
) else (
    set "REPO=%USERPROFILE%\roblox-flick-flock"
)

REM ---- Desktop shortcut named Al-kkagi (in Korean) -> open-studio.bat in the repo ----
REM Made first, before git, so it works even if git pull fails.
REM 1st try: PowerShell (also sets the Roblox Studio icon). Source: tools-src/make-shortcut.ps1
REM 2nd try: VBScript written to %TEMP% (classic Windows way, no icon).
echo [0/4] Making desktop shortcut ...
set "FF_REPO=%REPO%"
powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand JABFAHIAcgBvAHIAQQBjAHQAaQBvAG4AUAByAGUAZgBlAHIAZQBuAGMAZQAgAD0AIAAnAFMAdABvAHAAJwAKAHQAcgB5ACAAewAKACAAIAAgACAAJABkAGUAcwBrAHQAbwBwACAAPQAgAFsARQBuAHYAaQByAG8AbgBtAGUAbgB0AF0AOgA6AEcAZQB0AEYAbwBsAGQAZQByAFAAYQB0AGgAKAAnAEQAZQBzAGsAdABvAHAAJwApAAoAIAAgACAAIAAkAG4AYQBtAGUAIAA9ACAALQBqAG8AaQBuACAAWwBjAGgAYQByAFsAXQBdACgAMAB4AEMANQA0AEMALAAgADAAeABBAEUANABDACwAIAAwAHgAQQBFADMAMAApAAoAIAAgACAAIAAkAHAAYQB0AGgAIAA9ACAASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGQAZQBzAGsAdABvAHAAIAAoACQAbgBhAG0AZQAgACsAIAAnAC4AbABuAGsAJwApAAoAIAAgACAAIAAkAHQAYQByAGcAZQB0ACAAPQAgAEoAbwBpAG4ALQBQAGEAdABoACAAJABlAG4AdgA6AEYARgBfAFIARQBQAE8AIAAnAG8AcABlAG4ALQBzAHQAdQBkAGkAbwAuAGIAYQB0ACcACgAgACAAIAAgACQAcwBoAGUAbABsACAAPQAgAE4AZQB3AC0ATwBiAGoAZQBjAHQAIAAtAEMAbwBtAE8AYgBqAGUAYwB0ACAAVwBTAGMAcgBpAHAAdAAuAFMAaABlAGwAbAAKACAAIAAgACAAJABsAGkAbgBrACAAPQAgACQAcwBoAGUAbABsAC4AQwByAGUAYQB0AGUAUwBoAG8AcgB0AGMAdQB0ACgAJABwAGEAdABoACkACgAgACAAIAAgACQAbABpAG4AawAuAFQAYQByAGcAZQB0AFAAYQB0AGgAIAA9ACAAJAB0AGEAcgBnAGUAdAAKACAAIAAgACAAJABsAGkAbgBrAC4AVwBvAHIAawBpAG4AZwBEAGkAcgBlAGMAdABvAHIAeQAgAD0AIAAkAGUAbgB2ADoARgBGAF8AUgBFAFAATwAKACAAIAAgACAAJABsAGkAbgBrAC4ARABlAHMAYwByAGkAcAB0AGkAbwBuACAAPQAgACcARgBsAGkAYwBrACAARgBsAG8AYwBrACcACgAgACAAIAAgACQAcwB0AHUAZABpAG8AIAA9ACAARwBlAHQALQBDAGgAaQBsAGQASQB0AGUAbQAgACgASgBvAGkAbgAtAFAAYQB0AGgAIAAkAGUAbgB2ADoATABPAEMAQQBMAEEAUABQAEQAQQBUAEEAIAAnAFIAbwBiAGwAbwB4AFwAVgBlAHIAcwBpAG8AbgBzACcAKQAgAC0AUgBlAGMAdQByAHMAZQAgAC0ARgBpAGwAdABlAHIAIABSAG8AYgBsAG8AeABTAHQAdQBkAGkAbwBCAGUAdABhAC4AZQB4AGUAIAAtAEUAcgByAG8AcgBBAGMAdABpAG8AbgAgAFMAaQBsAGUAbgB0AGwAeQBDAG8AbgB0AGkAbgB1AGUAIAB8ACAAUwBlAGwAZQBjAHQALQBPAGIAagBlAGMAdAAgAC0ARgBpAHIAcwB0ACAAMQAKACAAIAAgACAAaQBmACAAKAAkAHMAdAB1AGQAaQBvACkAIAB7ACAAJABsAGkAbgBrAC4ASQBjAG8AbgBMAG8AYwBhAHQAaQBvAG4AIAA9ACAAJABzAHQAdQBkAGkAbwAuAEYAdQBsAGwATgBhAG0AZQAgACsAIAAnACwAMAAnACAAfQAKACAAIAAgACAAJABsAGkAbgBrAC4AUwBhAHYAZQAoACkACgAgACAAIAAgAGYAbwByAGUAYQBjAGgAIAAoACQAbwBsAGQAIABpAG4AIABAACgAKAAkAG4AYQBtAGUAIAArACAAJwAuAGIAYQB0ACcAKQAsACAAJwBGAGwAaQBjAGsAIABGAGwAbwBjAGsALgBsAG4AawAnACkAKQAgAHsACgAgACAAIAAgACAAIAAgACAAJABvAGwAZABQAGEAdABoACAAPQAgAEoAbwBpAG4ALQBQAGEAdABoACAAJABkAGUAcwBrAHQAbwBwACAAJABvAGwAZAAKACAAIAAgACAAIAAgACAAIABpAGYAIAAoAFQAZQBzAHQALQBQAGEAdABoACAAJABvAGwAZABQAGEAdABoACkAIAB7ACAAUgBlAG0AbwB2AGUALQBJAHQAZQBtACAAJABvAGwAZABQAGEAdABoACAALQBFAHIAcgBvAHIAQQBjAHQAaQBvAG4AIABTAGkAbABlAG4AdABsAHkAQwBvAG4AdABpAG4AdQBlACAAfQAKACAAIAAgACAAfQAKACAAIAAgACAAaQBmACAAKABUAGUAcwB0AC0AUABhAHQAaAAgACQAcABhAHQAaAApACAAewAKACAAIAAgACAAIAAgACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAKAAnAFsATwBLAF0AIABEAGUAcwBrAHQAbwBwACAAcwBoAG8AcgB0AGMAdQB0ADoAIAAnACAAKwAgACQAcABhAHQAaAAgACsAIAAnACAAIAAtAD4AIAAgACcAIAArACAAJAB0AGEAcgBnAGUAdAApAAoAIAAgACAAIAB9ACAAZQBsAHMAZQAgAHsACgAgACAAIAAgACAAIAAgACAAVwByAGkAdABlAC0ASABvAHMAdAAgACgAJwBbAEYAQQBJAEwAXQAgAFMAaABvAHIAdABjAHUAdAAgAHcAYQBzACAAbgBvAHQAIABjAHIAZQBhAHQAZQBkACAAYQB0ACAAJwAgACsAIAAkAHAAYQB0AGgAKQAKACAAIAAgACAAIAAgACAAIABlAHgAaQB0ACAAMQAKACAAIAAgACAAfQAKAH0AIABjAGEAdABjAGgAIAB7AAoAIAAgACAAIABXAHIAaQB0AGUALQBIAG8AcwB0ACAAKAAnAFsARgBBAEkATABdACAAJwAgACsAIAAkAF8ALgBFAHgAYwBlAHAAdABpAG8AbgAuAE0AZQBzAHMAYQBnAGUAKQAKACAAIAAgACAAZQB4AGkAdAAgADEACgB9AA==
if not errorlevel 1 goto shortcut_done
echo [0/4] PowerShell failed, trying VBScript ...
>"%TEMP%\flickflock_shortcut.vbs" echo Set sh = CreateObject("WScript.Shell")
>>"%TEMP%\flickflock_shortcut.vbs" echo Set fso = CreateObject("Scripting.FileSystemObject")
>>"%TEMP%\flickflock_shortcut.vbs" echo d = sh.SpecialFolders("Desktop")
>>"%TEMP%\flickflock_shortcut.vbs" echo n = ChrW(^&HC54C) ^& ChrW(^&HAE4C) ^& ChrW(^&HAE30)
>>"%TEMP%\flickflock_shortcut.vbs" echo Set l = sh.CreateShortcut(d ^& "\" ^& n ^& ".lnk")
>>"%TEMP%\flickflock_shortcut.vbs" echo l.TargetPath = "%REPO%\open-studio.bat"
>>"%TEMP%\flickflock_shortcut.vbs" echo l.WorkingDirectory = "%REPO%"
>>"%TEMP%\flickflock_shortcut.vbs" echo l.Save
>>"%TEMP%\flickflock_shortcut.vbs" echo If fso.FileExists(d ^& "\" ^& n ^& ".bat") Then fso.DeleteFile d ^& "\" ^& n ^& ".bat"
>>"%TEMP%\flickflock_shortcut.vbs" echo If fso.FileExists(d ^& "\Flick Flock.lnk") Then fso.DeleteFile d ^& "\Flick Flock.lnk"
>>"%TEMP%\flickflock_shortcut.vbs" echo If fso.FileExists(d ^& "\" ^& n ^& ".lnk") Then
>>"%TEMP%\flickflock_shortcut.vbs" echo   WScript.Echo "[OK] Desktop shortcut made in " ^& d
>>"%TEMP%\flickflock_shortcut.vbs" echo Else
>>"%TEMP%\flickflock_shortcut.vbs" echo   WScript.Echo "[FAIL] Shortcut not found in " ^& d
>>"%TEMP%\flickflock_shortcut.vbs" echo   WScript.Quit 1
>>"%TEMP%\flickflock_shortcut.vbs" echo End If
cscript //nologo "%TEMP%\flickflock_shortcut.vbs"
if errorlevel 1 (
    echo [WARN] Could not create the desktop shortcut. Please send this screen.
    pause
)
:shortcut_done

where git >nul 2>nul
if errorlevel 1 (
    echo [ERROR] Git is not installed.
    echo         Install it with:  winget install Git.Git
    echo         or download from https://git-scm.com/download/win
    pause
    exit /b 1
)

if not exist "%REPO%\.git" (
    echo [1/4] Setting up repo in %REPO% ...
    if not exist "%REPO%" mkdir "%REPO%"
    cd /d "%REPO%"
    git init -q
    git remote remove origin >nul 2>nul
    git remote add origin "%REPO_URL%"
    git fetch origin %BRANCH%
    if errorlevel 1 (
        echo [ERROR] git fetch failed. Check internet / GitHub login.
        pause
        exit /b 1
    )
    git checkout -f -B %BRANCH% origin/%BRANCH%
    git branch -u origin/%BRANCH% >nul
)

cd /d "%REPO%"
echo [1/4] git pull ...
git pull --ff-only
if errorlevel 1 (
    echo [WARN] git pull failed - continuing with local files. Local changes:
    git status --short
)

REM Hand off to the newest launcher inside the repo, so an old copy
REM (for example one saved on the Desktop) still runs the latest steps.
if /i not "%~3"=="--latest" (
    if exist "%REPO%\open-studio.bat" (
        copy /y "%REPO%\open-studio.bat" "%TEMP%\flickflock_latest.bat" >nul
        call "%TEMP%\flickflock_latest.bat" --from-temp "%REPO%\" --latest
        exit /b
    )
)


set "ROJO_DIR=%REPO%\tools\rojo-%ROJO_VERSION%"
set "ROJO=%ROJO_DIR%\rojo.exe"
if not exist "%ROJO%" (
    echo [2/4] Downloading Rojo %ROJO_VERSION% ...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "[Net.ServicePointManager]::SecurityProtocol='Tls12';" ^
      "$zip=Join-Path $env:TEMP 'rojo-%ROJO_VERSION%.zip';" ^
      "Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v%ROJO_VERSION%/rojo-%ROJO_VERSION%-windows-x86_64.zip' -OutFile $zip;" ^
      "Expand-Archive -Force $zip '%ROJO_DIR%'"
    if not exist "%ROJO%" (
        echo [ERROR] Rojo download failed.
        pause
        exit /b 1
    )
)

echo [2/4] Installing Rojo Studio plugin ...
"%ROJO%" plugin install

echo [3/4] Building %PLACE% and opening Roblox Studio ...
"%ROJO%" build -o "%PLACE%"
if errorlevel 1 (
    echo [ERROR] rojo build failed.
    pause
    exit /b 1
)
start "" "%REPO%\%PLACE%"

echo.
echo ============================================================
echo  Rojo server : localhost:%PORT%
echo  Studio account : %ROBLOX_ACCOUNT%
echo     If Studio shows another account, log out and log in as
echo     %ROBLOX_ACCOUNT% once. Studio remembers it after that.
echo  In Studio   : Plugins tab - Rojo - Connect
echo                address localhost, port %PORT%
echo  Keep this window open while working. Ctrl+C to stop.
echo ============================================================
echo.
echo [4/4] rojo serve ...
"%ROJO%" serve --port %PORT%
pause

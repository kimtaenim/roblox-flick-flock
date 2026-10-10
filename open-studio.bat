@echo off
REM ============================================================
REM  Flick Flock - local Studio launcher
REM  Copy this file to the Desktop and double-click it.
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
    echo [WARN] git pull failed - continuing with local files.
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

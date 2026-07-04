@echo off
title EchoSync Servers Startup
echo ==============================================
echo 🎵 SyncBeat / EchoSync Servers Launcher
echo ==============================================
echo.

:: Kill leftover processes on ports 5000 and 5001
echo [1/4] Cleaning ports 5000 and 5001...
taskkill /F /IM api_server.exe >nul 2>&1
taskkill /F /IM node.exe >nul 2>&1

:: Build Rust Backend
echo [2/4] Building Rust API Backend...
cd api_server
cargo build
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to build Rust backend.
    pause
    exit /b
)
cd ..

:: Start Rust Backend on Port 5000
echo [3/4] Starting Rust Backend (Port 5000) in new window...
start "EchoSync Rust API Server" cmd /k "cd api_server && cargo run"

:: Start Node.js Socket/Media Server on Port 5001
echo [4/4] Starting Node.js Server (Port 5001) in new window...
start "SyncBeat Node.js Socket Server" cmd /k "cd backend && node server.js"

echo.
echo ==============================================
echo ✅ Both servers successfully launched!
echo 🌐 Rust API: http://127.0.0.1:5000
echo 🌐 Node Socket: http://127.0.0.1:5001
echo ==============================================
echo.
pause

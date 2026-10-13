@echo off
rem Double-click to start the sprite tools page. -Elvie
title Emerald Lens sprite tools
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch\serve.ps1"
if errorlevel 1 pause

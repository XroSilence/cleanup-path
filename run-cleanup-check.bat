@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0cleanup-path.ps1' -WhatIf"
pause
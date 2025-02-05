@echo off
powershell -Command "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process; & '%~dp0cleanup-path.ps1'"
pause
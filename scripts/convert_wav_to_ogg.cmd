@echo off
setlocal

if "%~1"=="" goto usage
where ffmpeg >nul 2>nul
if errorlevel 1 (
    echo FFmpeg was not found. Install FFmpeg with libvorbis and add it to PATH.
    exit /b 1
)
if not exist "%~1" (
    echo Input file not found: "%~1"
    exit /b 1
)

set "INPUT=%~f1"
for %%I in ("%~dp0..\assets\audio") do set "AUDIO_DIR=%%~fI"
if not exist "%AUDIO_DIR%" mkdir "%AUDIO_DIR%"
if "%~2"=="" goto default_output
set "OUTPUT=%~f2"
goto check_output

:default_output
set "OUTPUT=%AUDIO_DIR%\%~n1.ogg"

:check_output
if exist "%OUTPUT%" (
    echo Output already exists: "%OUTPUT%"
    echo Choose a different output path or move the existing file first.
    exit /b 1
)

ffmpeg -hide_banner -n -i "%INPUT%" -vn -map_metadata -1 -c:a libvorbis -q:a 5 "%OUTPUT%"
if errorlevel 1 exit /b %errorlevel%
echo Created "%OUTPUT%"
exit /b 0

:usage
echo Usage: %~nx0 input.wav [output.ogg]
echo By default, the OGG is written to assets\audio with the input filename.
exit /b 2

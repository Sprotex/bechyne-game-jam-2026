@echo off
setlocal

set "ITCH_PROJECT="
set "GODOT="
goto parse_args

:parse_args
if "%~1"=="" goto args_done
if /I "%~1"=="-ItchProject" goto set_itch_project
if /I "%~1"=="-GodotExecutable" goto set_godot_executable
echo Unknown argument: %~1
goto usage_error

:set_itch_project
if "%~2"=="" goto usage_error
set "ITCH_PROJECT=%~2"
shift
shift
goto parse_args

:set_godot_executable
if "%~2"=="" goto usage_error
set "GODOT=%~2"
shift
shift
goto parse_args

:args_done
if not defined ITCH_PROJECT goto usage_error
set "PROJECT_ROOT=%~dp0.."
for %%I in ("%PROJECT_ROOT%") do set "PROJECT_ROOT=%%~fI"
set "BUTLER=%LOCALAPPDATA%\Programs\itch-butler\butler.exe"
set "WEB_BUILD=%PROJECT_ROOT%\build\web"

if not defined GODOT (
	for /f "delims=" %%G in ('where godot_console.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
)
if not defined GODOT (
	for /f "delims=" %%G in ('where godot4_console.exe 2^>nul') do if not defined GODOT set "GODOT=%%G"
)
if not defined GODOT set "GODOT=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64_console.exe"

if not exist "%GODOT%" (
	echo Godot executable not found: "%GODOT%"
	echo Pass its location as the second argument.
	exit /b 1
)
if not exist "%BUTLER%" (
	echo Butler not found: "%BUTLER%"
	exit /b 1
)

pushd "%PROJECT_ROOT%" || exit /b 1
if not exist "%WEB_BUILD%" mkdir "%WEB_BUILD%"

"%GODOT%" --headless --path "%PROJECT_ROOT%" --export-release "Web"
if errorlevel 1 (
	echo Godot Web export failed.
	popd
	exit /b 1
)
if not exist "%WEB_BUILD%\index.html" (
	echo Web export did not produce "%WEB_BUILD%\index.html".
	popd
	exit /b 1
)

"%BUTLER%" push "%WEB_BUILD%" "%ITCH_PROJECT%:html"
if errorlevel 1 (
	echo Butler Web upload failed.
	popd
	exit /b 1
)

popd
exit /b 0

:usage_error
echo Usage: %~nx0 -ItchProject owner/project-slug [-GodotExecutable path]
exit /b 2

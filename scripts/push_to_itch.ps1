param(
	[Parameter(Mandatory = $true)]
	[ValidatePattern('^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$')]
	[string]$ItchProject,
	[string]$GodotExecutable
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$butlerExecutable = Join-Path $env:LOCALAPPDATA 'Programs\itch-butler\butler.exe'

if (-not $GodotExecutable) {
	$godotCommand = Get-Command godot_console, godot4_console -ErrorAction SilentlyContinue | Select-Object -First 1
	if ($godotCommand) {
		$GodotExecutable = $godotCommand.Source
	} else {
		$GodotExecutable = Join-Path $env:USERPROFILE 'Downloads\Godot_v4.7.2-stable_win64_console.exe'
	}
}

if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
	throw "Godot executable not found at '$GodotExecutable'. Pass its location with -GodotExecutable."
}
if (-not (Test-Path -LiteralPath $butlerExecutable -PathType Leaf)) {
	throw "Butler not found at '$butlerExecutable'. Install Butler before uploading."
}

Push-Location $projectRoot
try {
	New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'build\web') | Out-Null
	& $GodotExecutable --headless --path $projectRoot --export-release 'Windows Desktop'
	$exportExitCode = $LASTEXITCODE
	if ($null -eq $exportExitCode) {
		throw 'Godot did not return an exit code. Pass the Godot console executable with -GodotExecutable.'
	}
	if ($exportExitCode -ne 0) {
		throw "Godot export failed with exit code $exportExitCode."
	}

	& $GodotExecutable --headless --path $projectRoot --export-release 'Web'
	$webExportExitCode = $LASTEXITCODE
	if ($null -eq $webExportExitCode) {
		throw 'Godot did not return an exit code while exporting Web.'
	}
	if ($webExportExitCode -ne 0) {
		throw "Web export failed with exit code $webExportExitCode."
	}

	$buildDirectory = Join-Path $projectRoot 'build\windows'
	$gameExecutable = Join-Path $buildDirectory 'gamejam-bechyne-2026.exe'
	if (-not (Test-Path -LiteralPath $gameExecutable -PathType Leaf)) {
		throw "Windows export did not produce '$gameExecutable'."
	}

	$channelTarget = "${ItchProject}:windows"
	& $butlerExecutable push $buildDirectory $channelTarget
	if ($LASTEXITCODE -ne 0) {
		throw "Butler upload failed with exit code $LASTEXITCODE."
	}

	$webBuildDirectory = Join-Path $projectRoot 'build\web'
	$webIndex = Join-Path $webBuildDirectory 'index.html'
	if (-not (Test-Path -LiteralPath $webIndex -PathType Leaf)) {
		throw "Web export did not produce '$webIndex'."
	}
	$webChannelTarget = "${ItchProject}:html"
	& $butlerExecutable push $webBuildDirectory $webChannelTarget
	if ($LASTEXITCODE -ne 0) {
		throw "Butler Web upload failed with exit code $LASTEXITCODE."
	}
} finally {
	Pop-Location
}

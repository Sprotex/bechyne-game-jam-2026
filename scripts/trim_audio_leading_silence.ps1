param(
    [string[]]$SoundNames = @('door', 'footsteps', 'lock', 'washing_machine', 'voice_message'),
    [string]$BackupName = (Get-Date -Format 'yyyy-MM-dd'),
    [switch]$FromBackup
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$audioDirectory = Join-Path $workspace 'assets\audio'
$backupDirectory = Join-Path $workspace "audio_sources\untrimmed\$BackupName"
Get-Command ffmpeg, ffprobe -ErrorAction Stop | Out-Null
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$edits = @{
    door = @{ Start = 30572 }
    footsteps = @{ Start = 28175 }
    lock = @{ Start = 147460; End = 154350 }
    washing_machine = @{ Start = 15321 }
    voice_message = @{ Start = 3158 }
}

foreach ($soundName in $SoundNames) {
    $source = Join-Path $audioDirectory "$soundName.wav"
    $backup = Join-Path $backupDirectory "$soundName.wav"
    $originalHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if (-not $edits.ContainsKey($soundName)) {
        throw "No reviewed sample range is configured for $soundName."
    }
    if (-not (Test-Path -LiteralPath $backup)) {
        if ($FromBackup) {
            throw "Cannot reprocess $soundName without its original backup."
        }
        Copy-Item -LiteralPath $source -Destination $backup
    }
    $backupHash = (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash
    if (-not $FromBackup -and $backupHash -ne $originalHash) {
        throw "Backup differs from source; choose a new BackupName before processing $soundName."
    }
    Write-Output "$soundName backup SHA256: $backupHash"
}

foreach ($soundName in $SoundNames) {
    $source = Join-Path $audioDirectory "$soundName.wav"
    $backup = Join-Path $backupDirectory "$soundName.wav"
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ("jam-trim-" + [guid]::NewGuid().ToString() + '.wav')
    try {
        $filter = 'atrim=start_sample=' + $edits[$soundName].Start
        if ($edits[$soundName].ContainsKey('End')) {
            $filter += ':end_sample=' + $edits[$soundName].End
        }
        $filter += ',asetpts=PTS-STARTPTS'
        & ffmpeg -hide_banner -loglevel error -n -i $backup -af $filter -c:a pcm_s16le $temporary
        if ($LASTEXITCODE -ne 0) {
            throw "FFmpeg failed for $soundName."
        }
        $originalDuration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $backup
        if ($LASTEXITCODE -ne 0) {
            throw "Cannot inspect original $soundName."
        }
        $trimmedDuration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $temporary
        if ($LASTEXITCODE -ne 0 -or [double]::Parse($trimmedDuration, [Globalization.CultureInfo]::InvariantCulture) -le 0.0) {
            throw "Invalid trimmed output for $soundName."
        }
        Copy-Item -LiteralPath $temporary -Destination $source -Force
        Write-Output "$soundName duration: $originalDuration -> $trimmedDuration seconds"
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary
        }
    }
}

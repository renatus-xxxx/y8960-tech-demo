param([string]$Work,[string]$Runtime)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if(!$Work){$Work=Join-Path $root ('logs/timing-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
$Work=[IO.Path]::GetFullPath($Work)
if(Test-Path -LiteralPath $Work){throw 'Choose a new output folder to avoid stale test data'}
[IO.Directory]::CreateDirectory($Work)|Out-Null
$m=Get-Content "$root/config/versions.json" -Raw|ConvertFrom-Json
. "$root/scripts/common.ps1"
if(!$Runtime){$Runtime=Join-Path $root 'runtime'}
VerifyRuntime $Runtime $m
CheckHash "$root/demo/Y8960-DEMO.rom" $m.demo.sha256
$meta=@{romSha256=(Get-FileHash "$root/demo/Y8960-DEMO.rom").Hash.ToLowerInvariant();emulatorCommit=$m.emulator.commit;assetsSha256=(Get-FileHash "$root/src/assets.h").Hash.ToLowerInvariant();emulatorSha256=(Get-FileHash (Join-Path $Runtime 'emulator/openmsx.exe')).Hash.ToLowerInvariant();date=(Get-Date -Format o)}
[IO.File]::WriteAllText("$Work/capture.json",($meta|ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
RunEmulator $Runtime $Work "$PSScriptRoot/timing.tcl" $true
if(!(Test-Path "$Work/CAPTURE.txt")){throw "Incomplete capture: $Work"}
python "$PSScriptRoot/analyze-timing.py" $Work
if($LASTEXITCODE -ne 0){throw "Audio timing regression: $Work/timing-results.json"}
Write-Host "PASS: audio timing and transition PCM. Results: $Work"

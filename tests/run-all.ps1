param([string]$Work,[string]$Runtime)
$ErrorActionPreference='Stop'
. "$PSScriptRoot/../scripts/common.ps1"
if(!$Work){$Work=Join-Path $RepoRoot ('logs/all-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
$Work=[IO.Path]::GetFullPath($Work)
if(Test-Path -LiteralPath $Work){throw 'Choose a new output folder'}
MakeDir $Work
if(!$Runtime){$Runtime=Join-Path $RepoRoot 'runtime'}
$Runtime=[IO.Path]::GetFullPath($Runtime)
$m=Get-Content "$RepoRoot/config/versions.json" -Raw|ConvertFrom-Json
VerifyRuntime $Runtime $m
CheckHash "$RepoRoot/demo/Y8960-DEMO.rom" $m.demo.sha256
foreach($test in @('smoke','audio-controls','loop','screens','adpcm-solo')){
 $dir=Join-Path $Work $test
 RunEmulator $Runtime $dir "$PSScriptRoot/$test.tcl" $true
 if(Test-Path "$dir/FAIL.txt"){throw (Get-Content "$dir/FAIL.txt" -Raw)}
 if($test -in @('smoke','audio-controls','loop') -and !(Test-Path "$dir/PASS.txt")){throw "Incomplete test: $test"}
}
python "$PSScriptRoot/analyze-audio.py" "$Work/audio-controls"
if($LASTEXITCODE){throw 'Audio analysis failed'}
python "$PSScriptRoot/analyze-screen.py" "$Work/screens/screen.bin"
if($LASTEXITCODE){throw 'Screen comparison failed'}
python "$PSScriptRoot/analyze-adpcm.py" "$Work/adpcm-solo"
if($LASTEXITCODE){throw 'ADPCM comparison failed'}
& "$PSScriptRoot/test-audio-timing.ps1" -Work "$Work/timing" -Runtime $Runtime
python "$PSScriptRoot/test-timing-analyzer.py" "$Work/timing"
if($LASTEXITCODE){throw 'Negative controls failed'}
& "$PSScriptRoot/validate-public.ps1"
WriteJson "$Work/suite-results.json" @{status='PASS';romSha256=$m.demo.sha256;emulatorCommit=$m.emulator.commit;tests=@('startup','controls','loop','audio','visual','adpcm','timing','negative-controls','public-files')}
Write-Host "PASS: all checks. Results: $Work"

param([string]$TestScript,[string]$Work)
. "$PSScriptRoot/common.ps1"
$m=Get-Content "$RepoRoot/config/versions.json" -Raw|ConvertFrom-Json
$runtime=Join-Path $RepoRoot 'runtime'
if(!(Test-Path "$runtime/receipt.json")){throw 'Run setup-y8960.bat first / 先に setup-y8960.bat を実行してください。'}
CheckLocal $RepoRoot;VerifyRuntime $runtime $m
CheckHash "$RepoRoot/demo/Y8960-DEMO.rom" $m.demo.sha256
if(!$Work){$Work=Join-Path $runtime 'user'}
$scriptFile=if($TestScript){[IO.Path]::GetFullPath($TestScript)}else{Join-Path $RepoRoot 'scripts/start.tcl'}
RunEmulator $runtime $Work $scriptFile ([bool]$TestScript)

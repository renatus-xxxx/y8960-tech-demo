param([string]$EmulatorZip)
. "$PSScriptRoot/common.ps1"
$lock=$null;$stage=$null
MakeDir (Join-Path $RepoRoot 'logs')
$log=Join-Path $RepoRoot ('logs/setup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.log')
Start-Transcript -LiteralPath $log | Out-Null
try{
 if(![Environment]::Is64BitOperatingSystem){throw 'Windows x64 required'}
 CheckLocal $RepoRoot
 $lock=[IO.File]::Open((Join-Path $RepoRoot 'logs/setup.lock'),'OpenOrCreate','ReadWrite','None')
 $m=Get-Content "$RepoRoot/config/versions.json" -Raw|ConvertFrom-Json
 CheckHash "$RepoRoot/demo/Y8960-DEMO.rom" $m.demo.sha256
 $runtime=Join-Path $RepoRoot 'runtime'
 if(Test-Path -LiteralPath $runtime){VerifyRuntime $runtime $m;Write-Host 'Verified existing installation / 既存環境の検査が完了しました。'}
 else{
  $cache=Join-Path $RepoRoot 'cache';MakeDir $cache
  if(!$EmulatorZip){$EmulatorZip=Join-Path $cache $m.emulator.file}
  if(!(Test-Path -LiteralPath $EmulatorZip)){
   if(!$m.emulator.url){throw 'The emulator download is not available yet. Check Releases; automatic setup requires published assets. See docs/publishing.md. / エミュレーターは配布準備中です。Releasesをご確認ください。公開後にsetupが自動取得します。詳細はdocs/publishing.ja.mdを参照してください。'}
   if($m.emulator.url -notmatch '^https://'){throw 'HTTPS required'}
   $part=$EmulatorZip+'.part'
   & "$env:SystemRoot/System32/curl.exe" --fail --location --proto '=https' --proto-redir '=https' --retry 2 --connect-timeout 20 --max-time 600 --output $part $m.emulator.url
   if($LASTEXITCODE -ne 0){throw 'Download failed / ダウンロードに失敗しました。'}
   CheckHash $part $m.emulator.sha256;Move-Item -LiteralPath $part -Destination $EmulatorZip
  }
  CheckHash $EmulatorZip $m.emulator.sha256
  $stage=Join-Path $RepoRoot ('.staging-'+[guid]::NewGuid().ToString('N'))
  ExpandSafe $EmulatorZip (Join-Path $stage 'emulator')
  CheckHash (Join-Path $stage 'emulator/openmsx.exe') $m.emulator.exeSha256
  $files=@(Get-ChildItem (Join-Path $stage 'emulator') -File -Recurse|ForEach-Object{[ordered]@{path=$_.FullName.Substring($stage.Length+1).Replace('\','/');sha256=(Hash $_.FullName)}})
  WriteJson (Join-Path $stage 'receipt.json') ([ordered]@{archiveSha256=$m.emulator.sha256;files=$files})
  $check=Join-Path $RepoRoot ('logs/setup-check-'+[guid]::NewGuid().ToString('N'))
  RunEmulator $stage $check (Join-Path $RepoRoot 'tests/smoke.tcl') $true
  if(!(Test-Path "$check/PASS.txt")){throw "Startup check failed. See $check"}
  Move-Item -LiteralPath $stage -Destination $runtime;$stage=$null
 }
 Write-Host "Ready: launch-y8960-tech-demo.bat / 起動準備ができました。`n$runtime"
}catch{Write-Host "ERROR: $_`nLog / ログ: $log" -ForegroundColor Red;throw}
finally{
 try{
 if($stage -and (Test-Path -LiteralPath $stage)){
  $full=[IO.Path]::GetFullPath($stage)
  $parent=[IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
  if((Split-Path $full -Parent) -ne $parent -or (Split-Path $full -Leaf) -notmatch '^\.staging-[0-9a-f]{32}$'){throw 'Refusing unsafe staging cleanup'}
  CheckLocal $full
  if(Get-ChildItem -LiteralPath $full -Force -Recurse | Where-Object {$_.Attributes -band [IO.FileAttributes]::ReparsePoint}){throw 'Refusing cleanup of linked staging contents'}
  Remove-Item -LiteralPath $full -Recurse -Force
 }
 }finally{if($lock){$lock.Dispose()};Stop-Transcript|Out-Null}}

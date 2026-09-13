param([string]$ZipPath)
. "$PSScriptRoot/../scripts/common.ps1"
$files=@(Get-Content "$RepoRoot/config/public-files.txt" | Where-Object {$_ -and !$_.StartsWith('#')})
if(($files|Sort-Object -Unique).Count -ne $files.Count){throw 'Duplicate allowlist entry'}
foreach($f in $files){
 if($f -match '(^|/)(runtime|cache|logs|build|dist|\.git)(/|$)' -or $f -match '(^/|:|\\|\.\.)'){throw "Unsafe public path: $f"}
 if(!(Test-Path -LiteralPath "$RepoRoot/$f" -PathType Leaf)){throw "Missing: $f"}
 CheckLocal "$RepoRoot/$f"
 if($f.EndsWith('.ps1')){$tok=$null;$err=$null;[Management.Automation.Language.Parser]::ParseFile("$RepoRoot/$f",[ref]$tok,[ref]$err)|Out-Null;if($err){throw ($err|Out-String)}}
 if($f.EndsWith('.md')){foreach($m in [regex]::Matches([IO.File]::ReadAllText("$RepoRoot/$f"),'\]\(([^)]+)\)')){$link=$m.Groups[1].Value;if($link -match '^(https?://|#)'){continue};$link=$link.Split('#')[0];if(!(Test-Path -LiteralPath (Join-Path (Split-Path "$RepoRoot/$f") $link))){throw "Broken link in ${f}: $link"}}}
}
if(Test-Path -LiteralPath "$RepoRoot/.git"){
 $tracked=@(& git -C $RepoRoot ls-files --cached --others --exclude-standard)
 if($LASTEXITCODE -ne 0){throw 'Could not inspect Git file list'}
 foreach($f in $tracked){if($f -notin $files){throw "Git-visible file is not in public allowlist: $f"}}
}
$bats=@(Get-ChildItem $RepoRoot -Filter '*.bat' -File|Select-Object -ExpandProperty Name|Sort-Object)
if(($bats -join ',') -ne 'launch-y8960-tech-demo.bat,setup-y8960.bat'){throw 'Expected exactly two root BATs'}
$m=Get-Content "$RepoRoot/config/versions.json" -Raw|ConvertFrom-Json
CheckHash "$RepoRoot/demo/Y8960-DEMO.rom" $m.demo.sha256
if($ZipPath){
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 $zip=[IO.Compression.ZipFile]::OpenRead([IO.Path]::GetFullPath($ZipPath))
 try{
  $names=@($zip.Entries|ForEach-Object{$_.FullName})
  if((Compare-Object ($files|Sort-Object) ($names|Sort-Object))){throw 'ZIP file list mismatch'}
  foreach($e in $zip.Entries){$s=$e.Open();$hash=[Security.Cryptography.SHA256]::Create();try{$h=[BitConverter]::ToString($hash.ComputeHash($s)).Replace('-','').ToLowerInvariant();if($h -ne (Hash "$RepoRoot/$($e.FullName)")){throw "ZIP content mismatch: $($e.FullName)"}}finally{$s.Dispose();$hash.Dispose()}}
 }finally{$zip.Dispose()}
}
Write-Host 'PASS: public files, hashes, scripts and links'

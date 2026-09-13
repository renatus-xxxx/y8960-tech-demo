$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
$RepoRoot=Split-Path -Parent $PSScriptRoot
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function CheckHash([string]$Path,[string]$Expected){if(!(Test-Path -LiteralPath $Path -PathType Leaf) -or (Hash $Path) -ne $Expected){throw "Missing or changed file / ファイルが不足または変更されています: $Path"}}
function MakeDir([string]$Path){[IO.Directory]::CreateDirectory($Path)|Out-Null}
function WriteJson([string]$Path,$Value){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))}
function CheckLocal([string]$Path){
 $p=[IO.Path]::GetFullPath($Path)
 while($p){if(Test-Path -LiteralPath $p){if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Use a normal local folder (no links/cloud placeholders) / リンク等を含まないローカルフォルダを使用してください: $p"}};$p=Split-Path -Parent $p}
}
function ExpandSafe([string]$Zip,[string]$To){
 Add-Type -AssemblyName System.IO.Compression.FileSystem
 MakeDir $To;$prefix=[IO.Path]::GetFullPath($To).TrimEnd('\')+'\'
 $z=[IO.Compression.ZipFile]::OpenRead($Zip)
 try{foreach($e in $z.Entries){$p=[IO.Path]::GetFullPath((Join-Path $To $e.FullName));if(!$p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or $e.FullName.Contains(':')){throw 'Unsafe ZIP entry'};if(!$e.Name){MakeDir $p;continue};MakeDir (Split-Path -Parent $p);[IO.Compression.ZipFileExtensions]::ExtractToFile($e,$p,$false)}}finally{$z.Dispose()}
}
function RunEmulator([string]$Runtime,[string]$Work,[string]$Script,[bool]$Test){
 MakeDir $Work
 $i=New-Object Diagnostics.ProcessStartInfo
 $i.FileName=Join-Path $Runtime 'emulator/openmsx.exe';$i.WorkingDirectory=$RepoRoot
 $i.UseShellExecute=$false;$i.CreateNoWindow=$Test
 if($Test){$i.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden}
 $i.EnvironmentVariables['OPENMSX_HOME']=$Work
 $i.EnvironmentVariables['OPENMSX_USER_DATA']=Join-Path $Work 'share'
 $i.EnvironmentVariables['OPENMSX_SYSTEM_DATA']=Join-Path $Runtime 'emulator/share'
 $argsList=@('-machine','C-BIOS_MSX2+','-carta',(Join-Path $RepoRoot 'demo/Y8960-DEMO.rom'),'-romtype','Normal4000','-extb','HRA_Y8960','-script',$Script)
 $i.Arguments=($argsList|ForEach-Object{'"'+$_+'"'}) -join ' '
 $i.RedirectStandardOutput=$true;$i.RedirectStandardError=$true
 $p=New-Object Diagnostics.Process;$p.StartInfo=$i
 if(!$p.Start()){throw 'Could not start openMSX'}
 $a=$p.StandardOutput.ReadToEndAsync();$b=$p.StandardError.ReadToEndAsync()
 if($Test){if(!$p.WaitForExit(180000)){$p.Kill();throw 'Emulator test timed out'}}else{$p.WaitForExit()}
 [IO.File]::WriteAllText((Join-Path $Work 'stdout.log'),$a.Result)
 [IO.File]::WriteAllText((Join-Path $Work 'stderr.log'),$b.Result)
 if($p.ExitCode -ne 0){throw "openMSX failed: $($b.Result)"}
}
function VerifyRuntime([string]$Runtime,$Manifest){
 $Runtime=[IO.Path]::GetFullPath($Runtime).TrimEnd('\\')
 CheckHash (Join-Path $Runtime 'emulator/openmsx.exe') $Manifest.emulator.exeSha256
 $r=Get-Content -LiteralPath (Join-Path $Runtime 'receipt.json') -Raw|ConvertFrom-Json
 if($r.archiveSha256 -ne $Manifest.emulator.sha256){throw 'Different installed emulator: use a new extraction folder / 別のエミュレーターです。新しいフォルダに展開してください。'}
 $expected=@($r.files | ForEach-Object {$_.path.Replace('\','/')})
 $actual=@(Get-ChildItem -LiteralPath (Join-Path $Runtime 'emulator') -Recurse -File -Force | ForEach-Object {$_.FullName.Substring($Runtime.Length+1).Replace('\','/')})
 if(Compare-Object $expected $actual){throw 'Unexpected or missing emulator files / エミュレーターファイルの追加・不足を検出しました。'}
 foreach($f in $r.files){$p=[IO.Path]::GetFullPath((Join-Path $Runtime $f.path));if(!$p.StartsWith($Runtime.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe receipt path'};CheckLocal $p;CheckHash $p $f.sha256}
}

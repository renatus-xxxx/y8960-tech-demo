param([string]$Z88dk)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Valid([string]$p){$p -and (Test-Path "$p/bin/zcc.exe") -and (Test-Path "$p/lib/config/msx.cfg")}
if($Z88dk){if(!(Valid $Z88dk)){throw 'Invalid -Z88dk directory'}}else{
 $candidates=@($env:Z88DK)
 if($env:ZCCCFG){$candidates+=Split-Path (Split-Path $env:ZCCCFG -Parent) -Parent}
 $z=Get-Command zcc.exe -ErrorAction SilentlyContinue;if($z){$candidates+=Split-Path (Split-Path $z.Source -Parent) -Parent}
 foreach($c in $candidates){if(Valid $c){$Z88dk=$c;break}}
 if(!$Z88dk){Add-Type -AssemblyName System.Windows.Forms;$d=New-Object Windows.Forms.FolderBrowserDialog;$d.Description='Select z88dk / z88dk のフォルダを選択';try{if($d.ShowDialog() -ne 'OK'){throw 'Selection cancelled / 選択をキャンセルしました。'};$Z88dk=$d.SelectedPath}finally{$d.Dispose()}}
 if(!(Valid $Z88dk)){throw 'Required z88dk files were not found'}
}
$savedPath=$env:PATH;$savedCfg=$env:ZCCCFG
Push-Location $root
try{
 $env:PATH="$Z88dk/bin;$env:PATH";$env:ZCCCFG="$Z88dk/lib/config"
 python "$PSScriptRoot/generate-assets.py";if($LASTEXITCODE -ne 0){throw 'Asset generation failed'}
 [IO.Directory]::CreateDirectory("$root/build")|Out-Null
 & "$Z88dk/bin/zcc.exe" +msx -subtype=rom -compiler=sdcc -SO3 -create-app src/main.c -o build/Y8960-DEMO -m
 if($LASTEXITCODE -ne 0){throw 'z88dk build failed'}
 $map=Get-Content build/Y8960-DEMO.map -Raw
 if($map -notmatch '__BSS_END_tail\s*=\s*\$([0-9A-Fa-f]+)'){throw 'BSS end symbol missing from linker map'}
 if([Convert]::ToInt32($Matches[1],16) -gt 0xc100){throw 'BSS overlaps telemetry'}
 if((Get-Item build/Y8960-DEMO.rom).Length -ne 16384){throw 'Expected 16 KiB ROM'}
 Copy-Item build/Y8960-DEMO.rom demo/Y8960-DEMO.rom -Force
 if(Test-Path config/versions.json){$m=Get-Content config/versions.json -Raw|ConvertFrom-Json;$m.demo.sha256=(Get-FileHash demo/Y8960-DEMO.rom).Hash.ToLowerInvariant();[IO.File]::WriteAllText("$root/config/versions.json",($m|ConvertTo-Json -Depth 8)+"`n",(New-Object Text.UTF8Encoding($false)))}
 Get-FileHash demo/Y8960-DEMO.rom
}finally{Pop-Location;$env:PATH=$savedPath;$env:ZCCCFG=$savedCfg}

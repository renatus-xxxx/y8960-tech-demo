param([string]$Output)
. "$PSScriptRoot/common.ps1"
& "$RepoRoot/tests/validate-public.ps1"
$m=Get-Content "$RepoRoot/config/versions.json" -Raw|ConvertFrom-Json
if(!$Output){$Output=Join-Path $RepoRoot "dist/y8960-tech-demo-$($m.version).zip"}
$Output=[IO.Path]::GetFullPath($Output)
if(Test-Path -LiteralPath $Output){throw "ZIP already exists: $Output"}
MakeDir (Split-Path -Parent $Output)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z=[IO.Compression.ZipFile]::Open($Output,'Create')
try{foreach($f in Get-Content "$RepoRoot/config/public-files.txt"){if($f -and !$f.StartsWith('#')){[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z,"$RepoRoot/$f",$f,'Optimal')|Out-Null}}}finally{$z.Dispose()}
& "$RepoRoot/tests/validate-public.ps1" -ZipPath $Output
Get-FileHash -LiteralPath $Output

# Run in a Visual Studio 2022 Developer PowerShell with C++/Win32 workload.
$ErrorActionPreference = 'Stop'
& msbuild (Join-Path $PSScriptRoot 'ExtIO_SWRadio.vcxproj') '/m' '/p:Configuration=Release' '/p:Platform=Win32'
if ($LASTEXITCODE -ne 0) { throw "MSBuild failed ($LASTEXITCODE)" }
Write-Host 'Copy the Win32 Release ExtIO_SWRadio.dll into the HDSDR directory.'

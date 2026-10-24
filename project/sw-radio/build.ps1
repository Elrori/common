# One-click build from Windows PowerShell with Vivado on PATH.
# .\build.ps1                   complete k9plus_ext bitstream build
# .\build.ps1 -SynthOnly        synth / utilization / timing only
param([switch]$SynthOnly)
$ErrorActionPreference = 'Stop'
$vivado = (Get-Command vivado.bat -ErrorAction SilentlyContinue)
if (-not $vivado) { $vivado = Get-Command vivado -ErrorAction SilentlyContinue }
if (-not $vivado) { throw 'Vivado not found. Run from a Vivado command prompt or add its bin to PATH.' }
if (-not $env:XILINX_VIVADO) { throw 'Vivado environment missing XILINX_VIVADO. Use Vivado command prompt.' }
$arguments = @('-mode','batch','-source', (Join-Path $PSScriptRoot 'scripts/build.tcl'))
if ($SynthOnly) { $arguments += @('-tclargs','-synth-only') }
& $vivado.Source @arguments
if ($LASTEXITCODE -ne 0) { throw "Vivado build failed with exit code $LASTEXITCODE" }
Write-Host 'See project/sw-radio/build/ for utilization, timing and DRC reports.'

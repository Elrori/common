[CmdletBinding()]
param(
    [string]$Vivado = "D:\XILINX\Vivado\2019.1\bin\vivado.bat",
    [string]$Bit = ""
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$bitPath = if ($Bit) {
    if ([IO.Path]::IsPathRooted($Bit)) { [IO.Path]::GetFullPath($Bit) }
    else { [IO.Path]::GetFullPath((Join-Path $root $Bit)) }
} else {
    Join-Path $root 'build\sw_radio_62m5_k9plus_ext.bit'
}
if (-not (Test-Path -LiteralPath $bitPath)) {
    throw "Build the bitstream first: $bitPath"
}
if (-not (Test-Path -LiteralPath $Vivado)) {
    throw "Vivado launcher not found: $Vivado"
}

# Volatile SRAM programming only.  This script never writes configuration
# flash, so power cycling restores the previously flashed image.
$bitTcl = $bitPath.Replace('\', '/')
$tclPath = Join-Path $root 'build\program_generated.tcl'
$tcl = @"
load_features labtools
open_hw
connect_hw_server
open_hw_target
set devices [get_hw_devices xc7a50t*]
if {[llength `$devices] != 1} {
    error "Expected exactly one XC7A50T JTAG device, found [llength `$devices]"
}
set dev [lindex `$devices 0]
current_hw_device `$dev
refresh_hw_device `$dev
set_property PROGRAM.FILE {$bitTcl} `$dev
program_hw_devices `$dev
refresh_hw_device `$dev
puts "SW_RADIO_PROGRAM_PASS device=`$dev"
close_hw
exit
"@
Set-Content -LiteralPath $tclPath -Value $tcl -Encoding ascii
& $Vivado -mode batch -nojournal -nolog -source $tclPath
if ($LASTEXITCODE -ne 0) {
    throw "Vivado programming failed with exit code $LASTEXITCODE"
}

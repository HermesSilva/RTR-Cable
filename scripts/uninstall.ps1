# RTR-Cable - removes the device and the driver package from the computer
# (run as administrator). Test-signing mode and the test certificate are
# left as they are: see the README to undo those.
$ErrorActionPreference = 'Stop'
$hardwareId = 'Root\AudioMirror'

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output 'Administrator rights are needed: asking Windows for them.'
    $shell = (Get-Process -Id $PID).Path
    Start-Process -FilePath $shell -Verb RunAs -ArgumentList @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    return
}

$devices = @(Get-PnpDevice -Class MEDIA -ErrorAction SilentlyContinue | Where-Object { $_.HardwareID -contains $hardwareId })
foreach ($device in $devices) {
    pnputil /remove-device $device.InstanceId
}

# The package in the driver store: the published name (oemNN.inf) whose
# original name is audiomirror.inf.
$published = $null
foreach ($line in (pnputil /enum-drivers)) {
    if ($line -match '(oem\d+\.inf)') { $published = $Matches[1] }
    if ($line -match 'audiomirror\.inf' -and $published) {
        pnputil /delete-driver $published /uninstall /force
        $published = $null
    }
}
Write-Output "Removed $($devices.Count) device(s)."

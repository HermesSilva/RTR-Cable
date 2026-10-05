# RTR-Cable - installs the driver package this script is in (run it from the
# unpacked package, as administrator).
#
# The package is test-signed. Windows loads a test-signed kernel driver only
# in test-signing mode, which needs Secure Boot switched off in the firmware:
#     bcdedit /set testsigning on      (then restart)
# This script does not change that setting: it checks it and stops if it is
# off. See the README for what test-signing mode means for the computer.
#
# What it does: trusts the test certificate of the package (machine stores
# Root and TrustedPublisher), creates the device Root\AudioMirror and
# installs the driver on it - what "devcon install AudioMirror.inf
# Root\AudioMirror" does, without needing devcon.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$inf = Join-Path $here 'AudioMirror.inf'
$hardwareId = 'Root\AudioMirror'

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'Run this script as administrator.'
}
if (-not (Test-Path $inf)) { Write-Error "AudioMirror.inf not found beside this script ($here)." }

$testSigning = (bcdedit /enum '{current}' | Select-String -Pattern 'testsigning\s+Yes') -ne $null
if (-not $testSigning) {
    Write-Error ("Test-signing mode is off: Windows will not load this driver. " +
                 "Switch Secure Boot off in the firmware, run 'bcdedit /set testsigning on', restart, and run this script again.")
}

$certificate = Join-Path $here 'RTR-Cable-test.cer'
if (Test-Path $certificate) {
    Import-Certificate -FilePath $certificate -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Import-Certificate -FilePath $certificate -CertStoreLocation Cert:\LocalMachine\TrustedPublisher | Out-Null
}

if (Get-PnpDevice -Class MEDIA -ErrorAction SilentlyContinue | Where-Object { $_.HardwareID -contains $hardwareId }) {
    Write-Output 'RTR-Cable is already installed: updating its driver.'
} else {
    # A root-enumerated device has to be created before a driver can be
    # installed on it.
    Add-Type -Namespace RtrCable -Name Setup -MemberDefinition @'
[StructLayout(LayoutKind.Sequential)]
public struct SP_DEVINFO_DATA { public uint cbSize; public Guid ClassGuid; public uint DevInst; public IntPtr Reserved; }
[DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern IntPtr SetupDiCreateDeviceInfoList(ref Guid ClassGuid, IntPtr hwndParent);
[DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool SetupDiCreateDeviceInfo(IntPtr DeviceInfoSet, string DeviceName, ref Guid ClassGuid, string DeviceDescription, IntPtr hwndParent, uint CreationFlags, ref SP_DEVINFO_DATA DeviceInfoData);
[DllImport("setupapi.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool SetupDiSetDeviceRegistryProperty(IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData, uint Property, byte[] PropertyBuffer, uint PropertyBufferSize);
[DllImport("setupapi.dll", SetLastError = true)]
public static extern bool SetupDiCallClassInstaller(uint InstallFunction, IntPtr DeviceInfoSet, ref SP_DEVINFO_DATA DeviceInfoData);
[DllImport("setupapi.dll", SetLastError = true)]
public static extern bool SetupDiDestroyDeviceInfoList(IntPtr DeviceInfoSet);
'@
    $mediaClass = [Guid]'4d36e96c-e325-11ce-bfc1-08002be10318'
    $set = [RtrCable.Setup]::SetupDiCreateDeviceInfoList([ref]$mediaClass, [IntPtr]::Zero)
    if ($set -eq [IntPtr]-1) { Write-Error 'SetupDiCreateDeviceInfoList failed.' }
    try {
        $data = New-Object RtrCable.Setup+SP_DEVINFO_DATA
        $data.cbSize = [Runtime.InteropServices.Marshal]::SizeOf($data)
        $DICD_GENERATE_ID = 1
        if (-not [RtrCable.Setup]::SetupDiCreateDeviceInfo($set, 'MEDIA', [ref]$mediaClass, 'RTR-Cable', [IntPtr]::Zero, $DICD_GENERATE_ID, [ref]$data)) {
            Write-Error "SetupDiCreateDeviceInfo failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
        }
        # The hardware id is a list of strings ended by an empty one.
        $bytes = [Text.Encoding]::Unicode.GetBytes($hardwareId + "`0`0")
        $SPDRP_HARDWAREID = 1
        if (-not [RtrCable.Setup]::SetupDiSetDeviceRegistryProperty($set, [ref]$data, $SPDRP_HARDWAREID, $bytes, $bytes.Length)) {
            Write-Error "SetupDiSetDeviceRegistryProperty failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
        }
        $DIF_REGISTERDEVICE = 0x19
        if (-not [RtrCable.Setup]::SetupDiCallClassInstaller($DIF_REGISTERDEVICE, $set, [ref]$data)) {
            Write-Error "SetupDiCallClassInstaller failed ($([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
        }
    } finally {
        [RtrCable.Setup]::SetupDiDestroyDeviceInfoList($set) | Out-Null
    }
}

# The driver goes into the store and onto every device with its hardware id.
pnputil /add-driver $inf /install
if ($LASTEXITCODE -ne 0) { Write-Error 'pnputil could not install the driver.' }
Write-Output ''
Write-Output 'Installed. In the sound settings of Windows:'
Write-Output '  playback  "RTR-Cable Input"   - what a player sends here goes into the cable'
Write-Output '  recording "RTR-Cable Output"  - the other end; in RTR-Bench it is an IN group on the rack'

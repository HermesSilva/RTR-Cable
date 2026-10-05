# RTR-Cable - builds the driver package (x64) into package\.
#
# Needs Visual Studio with the C++ workload and the Windows Driver Kit (WDK)
# with its Visual Studio extension. The GitHub workflow runs this same script.
#
#   -Debug   debug build (default: Release)
#   -Sign    test-signs the package with a self-signed certificate made for
#            this build (package\RTR-Cable-test.cer). Such a package loads
#            only on a computer in test-signing mode: see the README.
param(
    [switch]$Debug,
    [switch]$Sign
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$configuration = if ($Debug) { 'Debug' } else { 'Release' }

$msbuild = (Get-Command msbuild.exe -ErrorAction SilentlyContinue).Source
if (-not $msbuild) {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $msbuild = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
}
if (-not $msbuild) { Write-Error 'MSBuild not found: install Visual Studio with the C++ workload and the WDK.' }

# The WDK signs by itself only with a certificate in the store of the user;
# signing is done below instead, so the build is the same everywhere.
# InfVerif is skipped: MSBuild of 64 bits cannot load the 32-bit InfVerif.dll
# of the kit (the INF is still checked by Windows when the driver is installed).
& $msbuild (Join-Path $root 'AudioMirror.sln') /m /nologo /v:minimal `
    "/p:Configuration=$configuration" /p:Platform=x64 /p:SignMode=Off /p:SpectreMitigation=false /p:EnableInfVerif=false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$built = Join-Path $root "x64\$configuration\AudioMirror"
if (-not (Test-Path (Join-Path $built 'AudioMirror.sys'))) { Write-Error "no driver in $built" }
$package = Join-Path $root 'package'
if (Test-Path $package) { [System.IO.Directory]::Delete($package, $true) }
New-Item -ItemType Directory -Force $package | Out-Null
Copy-Item (Join-Path $built '*') $package -Recurse
Copy-Item (Join-Path $root 'scripts\install.ps1'), (Join-Path $root 'scripts\uninstall.ps1') $package
Copy-Item (Join-Path $root 'README.md'), (Join-Path $root 'CHANGELOG.md'), (Join-Path $root 'LICENSE.md') $package

if ($Sign) {
    $signtool = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if (-not $signtool) { Write-Error 'signtool.exe not found in the Windows Kits.' }
    $certificate = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=RTR-Cable test signing' `
        -CertStoreLocation Cert:\CurrentUser\My -NotAfter (Get-Date).AddYears(5)
    Export-Certificate -Cert $certificate -FilePath (Join-Path $package 'RTR-Cable-test.cer') | Out-Null
    foreach ($file in 'AudioMirror.sys', 'audiomirror.cat') {
        $target = Join-Path $package $file
        if (Test-Path $target) {
            & $signtool.FullName sign /fd sha256 /sha1 $certificate.Thumbprint $target
            if ($LASTEXITCODE -ne 0) { Write-Error "cannot sign $file" }
        }
    }
    Remove-Item "Cert:\CurrentUser\My\$($certificate.Thumbprint)" -Force
}
Get-ChildItem $package | ForEach-Object { Write-Output "package\$($_.Name)" }

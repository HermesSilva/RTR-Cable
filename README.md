# RTR-Cable

A virtual audio cable for Windows 10 and 11 (x64): a kernel driver that adds
a playback device, **RTR-Cable Input**, and a recording device, **RTR-Cable
Output**. Whatever a program plays on the first comes out of the second.
Nothing sounds on the speakers.

It is the companion of [RTR-Bench](https://github.com/HermesSilva/RTR-Bench):
a player sends its sound to *RTR-Cable Input*; on the rack of the bench
*RTR-Cable Output* is one of the **IN** groups of the audio strip, to be
wired into a circuit of the circuit bench and from there to a physical
output. The driver is installed apart from the bench and is useful without
it, with any program that records from a device.

RTR-Cable is a fork of [AudioMirror](https://github.com/JannesP/AudioMirror)
by Jannes Peters (MIT), itself derived from Microsoft's SYSVAD sample.

## State

**Experimental.** The upstream author's warning stands: the driver is not
finished. What this fork has today:

- the names the user sees are RTR-Cable (the file, service and hardware
  names are still those of AudioMirror, see [Names](#names));
- a script that builds the package, a workflow that builds it on every push,
  and scripts that install and remove it;
- **the driver is test-signed, not production-signed** (next section).

The workflow builds the package with the Windows Driver Kit 10.0.26100,
verifies the INF and test-signs the driver. Installation was **not** tested by the
fork yet: the computer it is developed on has no test-signing mode.

## Signing: read before installing

64-bit Windows loads a kernel driver only if Microsoft signed it. That takes
an Extended Validation code-signing certificate and a submission to the
Microsoft Hardware Dev Center, which this project does not have. The
packages built here are signed with a throw-away test certificate instead,
and Windows accepts those only in **test-signing mode**:

1. Secure Boot must be switched **off** in the firmware (UEFI) setup.
2. `bcdedit /set testsigning on` in an administrator console, then restart.
   The desktop shows "Test Mode" in a corner.

Test-signing mode lets *any* test-signed driver load, not only this one, and
some programs (anti-cheat of games, some DRM) refuse to run in it. Switching
Secure Boot off weakens the protection of the boot. Use a spare computer or
a virtual machine if that is not acceptable. To leave it:
`bcdedit /set testsigning off`, restart, switch Secure Boot back on.

## Install

1. Get the package: the `rtr-cable-x64` artifact of the latest
   [build](https://github.com/HermesSilva/RTR-Cable/actions/workflows/build.yml),
   or build it (below). Unpack it.
2. Put the computer in test-signing mode (above).
3. In an administrator PowerShell, in the unpacked folder:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\install.ps1
   ```

   The script checks test-signing mode, trusts the certificate of the
   package, creates the device and installs the driver. It changes nothing
   else. Should it fail to create the device, the manual way is Device
   Manager > Action > Add legacy hardware > Install from a list > Sound,
   video and game controllers > Have Disk > `AudioMirror.inf`.

4. In the sound settings of Windows there is now a playback device
   *RTR-Cable Input* and a recording device *RTR-Cable Output*.

To remove it: `.\uninstall.ps1` in an administrator PowerShell.

## Use with RTR-Bench

1. In the player (or in the volume mixer of Windows, per program) choose
   *RTR-Cable Input* as the output device.
2. Start RTR-Bench. The audio strip of the rack has an **IN** group named
   *RTR-Cable Output*: take a cable at its L or R jack and plug it into a
   point of the schematic.
3. Wire the point where the processed signal is to an **OUT** group (the
   speakers).

Without the driver the bench has another way that needs no installation: the
**PLAYING** group of each playback device, which taps what the computer is
playing there. The cable is for when the original sound must not be heard.

## Build

Visual Studio 2022 with the C++ workload, the Windows Driver Kit (WDK) and
its Visual Studio extension.

```powershell
scripts\build.ps1          # Release x64 into package\
scripts\build.ps1 -Sign    # and test-sign it with a certificate made for the build
```

The workflow in `.github/workflows/build.yml` runs `scripts\build.ps1 -Sign`
and publishes `package\` as the artifact `rtr-cable-x64`.

## Names

| What | Name |
|------|------|
| Playback device (the player sends here) | RTR-Cable Input |
| Recording device (the bench listens here) | RTR-Cable Output |
| Device in Device Manager | RTR-Cable |
| Driver file, service | `AudioMirror.sys`, `AudioMirror` |
| Hardware id | `Root\AudioMirror` |

The internal names are kept so that the fork stays easy to compare and merge
with upstream.

## Layout

```
AudioMirror/         the driver: PortCls adapter, WaveRT miniports, the ring buffer between them
AudioMirror.sln      the Visual Studio solution
scripts/             build.ps1, install.ps1, uninstall.ps1
.github/workflows/   the build
CHANGELOG.md
```

## License

MIT, as upstream: see [LICENSE.md](LICENSE.md). The driver derives from
Microsoft's SYSVAD sample (MS-PL).

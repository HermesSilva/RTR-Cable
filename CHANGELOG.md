# Changelog

All notable changes of this fork. Versions follow the driver package.

## Unreleased

Fork of [AudioMirror](https://github.com/JannesP/AudioMirror) at commit
`a9618d1` (2022-10-15), as the virtual audio cable of
[RTR-Bench](https://github.com/HermesSilva/RTR-Bench).

### Changed

- The names the user sees: playback device *RTR-Cable Input*, recording
  device *RTR-Cable Output*, device *RTR-Cable*, provider *RTR-Bench*. The
  file, service and hardware names are unchanged.
- README rewritten: what the driver is, the state it is in, what
  test-signing means, how to install, use with RTR-Bench, build and remove.

### Fixed

- Builds with the current Windows Driver Kit (10.0.26100): the Release
  configuration links the port class libraries (upstream set them up for
  Debug only), an `if` whose body is a debug print no longer ends in an
  empty statement, and the deprecation of `ExAllocatePoolWithTag` does not
  stop the build (the calls are unchanged).
- The INF declares `PnpLockdown=1`, as InfVerif asks.

### Added

- `scripts\build.ps1`: builds the x64 package into `package\`; `-Sign`
  test-signs it with a certificate made for the build.
- `scripts\install.ps1`: checks test-signing mode, trusts the certificate of
  the package, creates the root device and installs the driver, without
  devcon.
- `scripts\uninstall.ps1`: removes the device and the package from the
  driver store.
- GitHub workflow that builds and test-signs the package on every push and
  publishes it as the artifact `rtr-cable-x64`.
- This changelog.

- `install.ps1` and `uninstall.ps1` ask Windows for administrator rights
  when started without them, and `install.ps1` run from `scripts\` uses the
  package in `package\`.

### Known limits

- Test-signed only: needs Secure Boot off and test-signing mode. Production
  signing needs an EV certificate and the Microsoft Hardware Dev Center.
- The driver code is upstream's, which its author calls unfinished; the
  install scripts were not exercised on a computer yet.

# Chameleon Ultra GUI Plus 1.4.3

An independently maintained community build of Chameleon Ultra GUI, based on the
upstream open-source project and distributed under GPL-3.0. This is not an
official upstream release.

## Coexistence

- Windows uses the product name `Chameleon Ultra GUI Plus`, the company name
  `lyx7725`, and the executable `ChameleonUltraGUIPlus.exe`. Its settings live
  in a separate application-data directory from the original build.
- Android uses the application ID `io.github.lyx7725.chameleonultraguiplus`, so
  it can be installed next to the upstream app without uninstalling either one.
- On the first Windows start, if this build's data directory is empty and the
  original app's data directory exists, the original saved cards and settings
  are copied once. The original files are only read and are never modified or
  moved.
- Saves and settings stay separate after that first copy.

## Changes from upstream

- Windows remembers window position, size, and maximized state.
- Windows USB scanning skips Bluetooth virtual serial ports that would block the
  UI isolate.
- The home page shows Demo-mode and unsupported-firmware warnings again.
- Windows BLE reconnects create a fresh communicator so stale command timeouts
  do not survive the reconnect.
- Application update checks read the latest release of this repository and fail
  silently when the network is unavailable.

## Building

Windows: install Flutter 3.47 or newer and the Visual Studio 2022 “Desktop
development with C++” workload.

```powershell
flutter pub get
flutter build windows --release
```

Android: install Flutter 3.47 or newer, JDK 17, Android SDK Platform 37, and
NDK 28.2. Release builds require your own release keystore configured in
`android/key.properties`.

```powershell
flutter pub get
flutter build apk --release --target-platform android-arm64
```

## Notes

- The PIN is validated by the device firmware. Enable BLE pairing in the device
  settings and restart the device before connecting.
- If an app with the same application ID but a different signature is already
  installed, uninstall that app before installing this build. Export saved cards
  first.
- The license and upstream copyright notices remain in the repository.

## License

GPL-3.0. Original project and copyright notices remain in the repository.
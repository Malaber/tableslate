# Background TestFlight release

TableSlate releases are built and uploaded with Xcode's command-line tools. The process runs in the background and must not open the Xcode GUI.

## Prerequisites

- Xcode and XcodeGen are installed.
- The Mac has the correct Apple Developer account, distribution certificate, and automatic-signing access.
- App Store Connect contains TableSlate with bundle ID `de.malaber.tableslate`.
- `project.yml` contains the intended marketing version and build number.
- `ExportOptions.TestFlight.plist` contains team `VWKG94374J`, automatic signing, App Store Connect upload, symbol upload, and Xcode-managed build numbering.
- The commit being shipped is current, clean, tested, and not superseded.

## Archive and upload

Run from `ios/TableSlateIOS`:

```bash
RELEASE_DIR="$(mktemp -d /private/tmp/tableslate-testflight.XXXXXX)"

xcodegen generate

xcodebuild \
  -project TableSlateApp.xcodeproj \
  -scheme TableSlate \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$RELEASE_DIR/TableSlate.xcarchive" \
  -derivedDataPath "$RELEASE_DIR/DerivedData" \
  -allowProvisioningUpdates \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$RELEASE_DIR/TableSlate.xcarchive" \
  -exportPath "$RELEASE_DIR/Export" \
  -exportOptionsPlist ExportOptions.TestFlight.plist \
  -allowProvisioningUpdates
```

The second command performs the App Store Connect upload. Success is confirmed only when its output contains both `Upload succeeded` and `** EXPORT SUCCEEDED **`. Xcode may then report that the package is processing.

Do not use `open`, `xed`, AppleScript, or other GUI automation for this workflow. Do not commit the generated `.xcodeproj`, derived data, archive, export output, or distribution logs.

## Verify and hand off

1. Confirm the reported marketing version, build number, bundle ID, and Apple app ID in the distribution log.
2. Confirm the build appears and finishes processing in App Store Connect.
3. Add it to an internal TestFlight group and install it on physical iPhone and iPad.
4. Record and push any source or release-configuration change made for the upload.

The 2026-09-15 baseline upload was version `0.1.0`, build `1`, Apple app ID `6812439555`.

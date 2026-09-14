# Native iPad support

Verified September 10, 2026 using local source at `23e7869de875805a8feb1b3b9461c294b75c8510` plus the uncommitted workspace changes. No App Store upload or version bump was performed.

## Saved device and build

- Reuse **Band Practice — iPad**, iPad Pro 11-inch (M5), iOS 26.5, UDID `0F817990-7B75-4F05-8D3C-BBBD0CC46754` across tasks and worktrees. This was an existing simulator assigned to the app; no per-task device is needed.
- Installed Debug simulator app: **1.3.0 (8)**, bundle `com.keithbarney.heavybandmanager.local`; compiled `UIDeviceFamily` is `[1, 2]`.
- Native tabs adapt to an iPad sidebar/top bar; iPhone retains system tabs. Lists preserve sidebar safe areas and limit excess width in wide windows.
- App supports portrait and landscape on iPad. Do not assume window resizing, Stage Manager, hardware keyboard, or physical-iPad behavior has been exhaustively tested.

```sh
xcodegen generate
xcodebuild -project HeavyBandManager.xcodeproj -scheme HeavyBandManager \
  -configuration Debug -destination 'platform=iOS Simulator,id=0F817990-7B75-4F05-8D3C-BBBD0CC46754' \
  -derivedDataPath /tmp/heavy-band-manager-ipad-build AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW build
xcrun simctl install 0F817990-7B75-4F05-8D3C-BBBD0CC46754 /tmp/heavy-band-manager-ipad-build/Build/Products/Debug-iphonesimulator/HeavyBandManager.app
xcrun simctl launch 0F817990-7B75-4F05-8D3C-BBBD0CC46754 com.keithbarney.heavybandmanager.local
```

Reuse the device even when shut down, and coordinate access before installing or navigating. Keep build output separate from other tasks.

## Verification

- 12 XCTest tests passed on the saved iPad. Repository `make preflight` also passed, including an unsigned Release device build.
- Installed Simulator walkthrough: Calendar, scheduled day details and dismissal, Automatic/Manual availability, calendar selection and return, mock availability save, Band and Settings. Increased regular-width calendar cells to 84 points and bounded the calendar width.
- Verified native portrait/landscape layouts, sidebar navigation, and Light/Dark appearance. Rebuilt and rechecked sidebar spacing after preserving the system safe area.
- Review runs use isolated mock data, with the review header intentionally visible. Normal production data and external services were not used for these checks.
- Build/test evidence for this local run is under `/tmp/heavy-band-manager-ipad-*`. Temporary review images are not App Store screenshot deliverables.

- iPhone smoke check on the same universal Debug artifact: Band Practice — Native UI (`CD8615C1-C30E-41B6-ADB6-D416DC1F29CD`): calendar layout and day-detail navigation.

## Screenshot handoff

Use the core inventory in `AGENTS.md`, native device layouts, stable filenames and the four canonical device/appearance folders. This implementation does not refresh the maintained App Store screenshot matrix. Use an explicit mock capture mode that hides review controls, verify actual appearance and native dimensions, and replace matching files only after validation. Never reuse a padded iPhone image as native iPad evidence.

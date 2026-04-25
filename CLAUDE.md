# Heavy Band Manager (Band Practice)

iOS app for bands to coordinate rehearsal scheduling via shared availability calendars.

## Stack
- SwiftUI, iOS 26 deployment target, Swift 5.9
- Supabase (auth + data), Apple Sign-In
- DialKit (Swift package)
- xcodegen for project generation (`project.yml` is source of truth)

## Identity
- **Bundle ID:** `com.keithbarney.heavybandmanager`
- **App Store name:** Band Practice
- **Display name (CFBundleDisplayName):** Band Practice
- **Team ID:** `BXKNJTU253`
- **Categories:** Music (primary), Productivity (secondary)

## App Store Submission

**Status:** v0.1.0, full public submission planned. App Store Connect record not yet created. Apple Developer Program enrolled (paid).

**Listing decisions:**
- Screenshots: iPhone 6.9" only (1320×2868), captured from simulator (`xcrun simctl io <UDID> screenshot`). Apple auto-scales for smaller devices. Project is `TARGETED_DEVICE_FAMILY: "1"` (iPhone only) — no iPad screenshots needed.
- Icon: placeholder for v0.1.0; replace before public review submission.
- Description / keywords / promo text: Claude drafts, Keith reviews.
- Privacy policy + support: GitHub Gists, following existing pattern (`<App Name> — Privacy Policy` / `<App Name> — Support`). See gists `e5755b85` (Sports Calendar Sync privacy) for reference template.
- iOS 26 deployment target: keeping for now, revisit if Apple flags.

## Conventions
- **Source of truth:** `project.yml` — never edit `.xcodeproj` directly. Run `xcodegen` after changes.
- **Screens named to match Figma:** SwiftUI struct names mirror Figma frame names (see `figma-sync.md` and recent commit `0ed2748`).
- **Screenshot mode:** `SCREENSHOT_MODE` flag in AuthGate bypasses login + shows mock data. Set to `false` before committing.
- **Secrets:** `HeavyBandManager/Secrets.swift` (not committed) holds Supabase URL/anon key.

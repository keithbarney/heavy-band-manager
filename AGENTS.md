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
- Description / keywords / promo text: Codex drafts, Keith reviews.
- Privacy policy + support: GitHub Gists, following existing pattern (`<App Name> — Privacy Policy` / `<App Name> — Support`). See gists `e5755b85` (Sports Calendar Sync privacy) for reference template.
- iOS 26 deployment target: keeping for now, revisit if Apple flags.

## Conventions
- **Source of truth:** `project.yml` — never edit `.xcodeproj` directly. Run `xcodegen` after changes.
- **Screens named to match Figma:** SwiftUI struct names mirror Figma frame names (see `figma-sync.md` and recent commit `0ed2748`).
- **Screenshot mode:** `SCREENSHOT_MODE` flag in AuthGate bypasses login + shows mock data. Set to `false` before committing.
- **Secrets:** `HeavyBandManager/Secrets.swift` (not committed) holds Supabase URL/anon key.

## Project Tracking
- **System of record:** This project is managed in Linear.
- **Linear workspace:** `keithbarney`
- **Linear team:** `Keithbarney` (`HVY`), team ID `6a009cce-8860-4dd0-b31f-6a4a18ccf65c`
- **Linear project:** [Band Practice](https://linear.app/keithbarney/project/band-practice-d81b35bd242d), project ID `a27746c2-067c-4970-b160-26566f3c64f0`
- **Linear initiative:** [Build apps I can use](https://linear.app/keithbarney/initiative/build-apps-i-can-use-4d20874290c7), initiative ID `8325a636-abb1-4ea6-a9f3-a3d48ab1336b`
- **Issue prefix:** `HVY`
- **Repository:** `git@github.com:keithbarney/heavy-band-manager.git`
- The Linear project was moved back to `In Progress` on July 30, 2026 for a production-hardening phase.
- For product plans and non-trivial implementation work, locate or create the corresponding Linear issue before work begins.
- Keep Linear current with scope, acceptance criteria, decisions, progress, blockers, validation results, and the next action.
- Update issue status as work moves through planning, implementation, review, QA, and completion. Do not treat chat-only plans or progress reports as sufficient project tracking.

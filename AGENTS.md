# Heavy Band Manager (Band Practice)

iOS app for bands to coordinate rehearsal scheduling via shared availability calendars.

## Stack
- SwiftUI, iOS 26 deployment target, Swift 5.9
- Supabase (auth + data), Apple Sign-In
- DialKit (Swift package)
- xcodegen for project generation (`project.yml` is source of truth)

## Identity
- **Bundle ID:** `com.keithbarney.heavybandmanager`
- **App Store name:** Band Practice Calendar
- **Display name (CFBundleDisplayName):** Band Practice
- **Apple ID:** `6763776073`
- **App Store:** https://apps.apple.com/us/app/band-practice-calendar/id6763776073
- **Team ID:** `BXKNJTU253`
- **Categories:** Music (primary), Productivity (secondary)

## App Store Releases

**Status:** Live on the public App Store. Current repository version is `1.2.0 (7)`.

**Listing decisions:**
- Screenshots: iPhone 6.9" only (1320×2868), captured from simulator (`xcrun simctl io <UDID> screenshot`). Apple auto-scales for smaller devices. Project is `TARGETED_DEVICE_FAMILY: "1"` (iPhone only) — no iPad screenshots needed.
- Description / keywords / promo text: Codex drafts, Keith reviews.
- Privacy policy: https://gist.github.com/keithbarney/7a8b49cec4807927f0a3368daa9eff71
- Support: https://gist.github.com/keithbarney/9fa6589b17e69b4f6efe21905072e5bb
- iOS 26 deployment target: keeping for now, revisit if Apple flags.
- Release commands and GitHub environment setup are documented in `marketing/RUNBOOK.md`.
- App Store Connect upload may be automated after validation; selecting a build for App Review and releasing it to customers require explicit user approval.

## Conventions
- **Source of truth:** `project.yml` — never edit `.xcodeproj` directly. Run `xcodegen` after changes.
- **Screens named to match Figma:** SwiftUI struct names mirror Figma frame names (see `figma-sync.md` and recent commit `0ed2748`).
- **Screenshot mode:** `SCREENSHOT_MODE` flag in AuthGate bypasses login + shows mock data. Set to `false` before committing.
- **Secrets:** `HeavyBandManager/Secrets.swift` (not committed) holds Supabase URL/anon key.
- **Release artifacts:** `.release/` is generated and ignored.
- **Versioning:** Run `make version VERSION=x.y.z` to update `project.yml`; never edit the generated Xcode project.

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

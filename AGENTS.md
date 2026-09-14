# Repository Guidelines

## Project Structure & Module Organization

This is a SwiftUI iOS app for coordinating band rehearsals. Application code is in `HeavyBandManager/`, organized into models, views, services, and shared extensions. Unit tests live in `HeavyBandManagerTests/`. `project.yml` is the XcodeGen source of truth. Backend schema, migrations, seed data, and rollout SQL are under `supabase/`; release automation is in `scripts/release.sh` and `Makefile`; marketing assets and release notes are under `marketing/` and `release/`.

## Build, Test, and Development Commands

- `xcodegen generate` — regenerate `HeavyBandManager.xcodeproj` after changing `project.yml`.
- `make preflight` — generate the project, run XCTest, and perform an unsigned Release build.
- `make resolve-packages` — resolve Swift packages and refresh `release/Package.resolved`.
- `make archive` — create a signed archive in `.release/`; requires release secrets and signing setup.
- `make version VERSION=1.3.0 [BUILD=8]` — update the marketing version and build number.
- `make upload` / `make release` — upload or run the full release flow; use only with the required credentials and explicit confirmation.

Open the generated `.xcodeproj` in Xcode to run the app on an iPhone simulator or device.

## Coding Style & Naming Conventions

Use standard Swift formatting with four-space indentation, one declaration per line, and clear early returns. Name SwiftUI views, models, and services in `PascalCase`; properties, methods, and test methods in `camelCase`. Keep Figma-aligned screen names consistent with `figma-sync.md`. Never edit the generated `.xcodeproj` directly.

## Testing Guidelines

Tests use XCTest and are named `*Tests.swift`, with methods named `test<Behavior>`. Run `make preflight` before submitting changes. Database changes should be validated with the Supabase local test workflow used by CI (`supabase db start` followed by `supabase test db ...`).

## Commit & Pull Request Guidelines

Use short, imperative commit subjects. Existing history commonly uses prefixes such as `feat:`, `fix:`, `chore:`, `release:`, and `runbook:`; follow that style when applicable. Pull requests should explain the user-visible change, list validation commands, include simulator screenshots for UI changes, and call out migrations, generated files, or release configuration affected.

## Security & Configuration

Do not commit `HeavyBandManager/Secrets.swift`, Supabase keys, signing credentials, or App Store Connect API keys. Keep `SCREENSHOT_MODE` set to `false` before committing or releasing. Treat `project.yml`, migrations, and `release/Package.resolved` as reviewed source files; generated artifacts belong in ignored output locations.

## Screenshot storage

Use `/Users/keithbarney/Documents/Github/heavy-band-manager/screenshots` from every checkout/worktree, with `<iphone|ipad>/<light|dark>/<number>-<device>-<appearance>-<screen-name>.png`. Replace validated matching captures in place and add only missing screens/variants. Keep manifest/validation metadata in the root and no dated folders or duplicate upload sets. Follow `/Users/keithbarney/Documents/Github/AGENTS.md` and `screenshots/README.md`; do not save maintained review images under `marketing/screenshots` or `.release`.

## Core screens for screenshots

The core App Store story is **automatically find shared time → confirm a practice → synchronize the confirmed practice to members’ personal calendars**. Members can supply availability automatically from personal calendar events or manually from chosen weekly hours. These are equally valid inputs to automatic overlap calculation; automatic availability does not mean automatic booking.

The revised marketing inventory below is the default for future refreshes. Use native iPhone/iPad Light/Dark unless Keith explicitly narrows scope. The September 13 five-card story is complete across **iPhone/iPad × Light/Dark**. The approved iPhone Light set retains its original provenance; the other three sets now use the same benefits and Minor Threat fixture. Stable IDs identify screens, not display order.

| Order | ID / filename slug | Benefit headline (two lines) | Native supporting content |
| --- | --- | --- | --- |
| 1 | 1 / `calendar` | Find time for everyone.<br>Automatically. | Native calendar overview with mixed green all-member and yellow partial-match dots, plus exactly four scheduled practices. |
| 2 | 12 / `confirmation` | Pick a time.<br>Confirm your practice. | Real Schedule Practice confirmation for an unscheduled all-four 7–9 PM window. Exercise Schedule and verify the saved practice afterward. |
| 3 | 13 / `personal-calendar` | Confirmed practices.<br>In everyone’s calendar. | Apple Calendar showing sample Minor Threat practices. This selected revision preserves the existing card and its provenance. |
| 4 | 8 / `availability-automatic` | Auto-sync your availability.<br>Or set it manually. | Full-width native Automatic availability screen with its explanation and the Manual tab visible, communicating both options. |
| 5 | 14 / `appearance` | Light or dark.<br>Make it yours. | Overlapping Band Light/Dark screens, Dark in front, with photographed members and logo. |


Use the approved white/SF Semibold template. Keith approved the opening headline and requested the monthly calendar UI in his September 13 annotations. `--screenshot-story --screenshot-band=minor-threat` supplies different member hours: Ian 7–10 PM, Lyle 6–9 PM, Brian 7–9:30 PM, Jeff 6:30–10 PM. Green dots show all four can attend; yellow dots show a valid partial overlap with the band’s minimum set to three of four. The fixture has four scheduled practices at offsets +8, +11, +15 and +17 days; the confirmation route uses an unscheduled day at +4. Native automation verifies the dot semantics and four upcoming practices before capturing the grid, then exercises confirming the extra practice.

Native inputs are Calendar (ID1), confirmation (ID12), Automatic (ID8), Apple Calendar (ID13), and Band Light/Dark (ID11) for Appearance (ID14). Keep raw inputs outside maintained marketing folders. Use `scripts/compose-benefits.py`; scoped runs preserve unselected cards and their provenance. One availability card communicates both options; do not include a separate Manual card in the marketing selection.

Settings and Band administration are no longer individual cards in the revised store selection. Preserve untouched variants until they are refreshed; retire obsolete images only in the selected variant after the replacement set passes visual/file checks. Do not add accessibility, developer controls, onboarding, search, errors, or extra sheets to the default selection.

Calendar delivery depends on each member’s calendar authorization and the app’s synchronization lifecycle. Current code creates a local event when scheduling, and reconciles members’ local events after practice loading/refresh. Do not promise instant background delivery or claim the screenshot run verified every member’s device. `scripts/BandCalendarDemo.swift` stages explicitly fictional events in a Simulator-local calendar only; it is never an app target. Record this as a manual demonstration, not an end-to-end sync result. Mock app services must continue to block real calendar and backend writes.

## Mock Artwork

Keith approved using the app’s normal member initials and band icon for the fictional screenshot band on September 12, 2026. These are intentional native representations, not failed artwork loads. Keep the same identities across devices and appearances. Do not add unrelated logos or portraits. On September 13 Keith requested Minor Threat photos and logo for the next iPhone Light iteration. Use the named, opt-in Minor Threat fixture below for that content and retain initials/icon for the default Night Shift fixture.

## iPad development simulator

Reuse iPad Pro 11-inch (M5) on iOS 26.5, UDID `0F817990-7B75-4F05-8D3C-BBBD0CC46754`, for this app’s iPad development and review across tasks/worktrees. This existing device was assigned to the project on September 10, 2026. Use isolated opt-in mock data; do not erase it or create another task-specific iPad. Native universal Debug builds were installed and reviewed on September 10, 2026, including portrait/landscape, adaptive tabs/sidebar, main screens, and Light/Dark appearance. See `docs/ipad-support.md` for build and review evidence. Capture and validate the core screenshot matrix separately before declaring screenshot delivery complete.

## Saved App Store capture devices — September 12, 2026

Use these project-owned devices for native App Store capture at the main required sizes; keep reusing them across tasks and appearances. Older smaller devices remain development-only and should not be erased.

- iPhone: **Band Practice — App Store iPhone**, iPhone 17 Pro Max, iOS 26.5, `F8B9CCD6-B79A-47B2-8553-1AAE8DFA3C80`, 1320 × 2868. Adopted an existing unassigned simulator.
- iPad: **Band Practice — App Store iPad**, iPad Pro 13-inch (M5), iOS 26.5, `5F3838DB-3E87-46A1-93C6-F8E84363CD5C`, 2064 × 2752. Created once because the saved 11-inch development device does not cover the required 13-inch slot.

Apple screenshot specifications rechecked September 12, 2026: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

### Minor Threat iPhone Light review fixture (September 13, 2026)

- Keith requested a second pass using Minor Threat, member photos and the band logo. The original four-member lineup is Ian MacKaye (Vocals), Lyle Preslar (Guitar), Brian Baker (Bass), Jeff Nelson (Drums). The previous initials/icon approval remains valid for the default Night Shift fixture; this named fixture uses the artwork documented in `Fixtures/MinorThreat/SOURCES.md`.
- Pass `--story --band minor-threat` to the capture helper (launch argument `--screenshot-band=minor-threat`). Keep the same isolated availability windows and fictional practices. Mock artwork is bundled only in the opt-in Debug Simulator build.
- The current iPhone Light story has five cards, including the calendar overview and a combined availability benefit. Appearance (ID14) now compares the Band screen (native ID11) in Light and Dark, showing the logo and four photographed members. The Automatic screen supplies the single availability card, with Manual visible in the segmented control. All four delivered variants use this five-card Minor Threat story.
- Day Detail uses the shared MemberAvatar view for member rows and matching-window avatars, so real uploaded member photos also display there.
- The Apple Calendar card is an independently staged, simulator-local illustration named `Minor Threat Practice`, not evidence of cross-device sync or actual band rehearsals.

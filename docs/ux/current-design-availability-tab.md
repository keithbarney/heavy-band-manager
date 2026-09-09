# Current design with an Availability tab

Branch: `codex/current-design-availability-tab`, based on `main` at `a3a4df4`. The broader native redesign remains on `codex/native-ios-ui`.

The app keeps its existing calendar, month scrolling, availability dots, confirmed practice circles, scheduling sheets, appearance, and settings. Navigation is now Calendar · Availability · Settings. The middle tab uses the existing My Availability editor for automatic calendar-based availability or manual weekly hours. Save stays in the tab and shows the existing success toast. The calendar setup card and Settings shortcut route to that same tab. Changing bands recreates the editor so another band's draft cannot appear there.

The calendar observes full availability-slot changes, including updated hours with an unchanged slot count, so its cached dots refresh after editing availability.

## Isolated simulator review

The opt-in Debug condition `AVAILABILITY_TAB_PREVIEW` provides Calendar overview, Automatic availability, No matching times, Setup needed, Save failure, and Long names. Every scenario owns in-memory band and calendar stores. Switching preserves saved edits; Reset affects only the selected scenario. The persistent Mock data header remains visible while navigating. Unsaved drafts reset when changing scenarios.

This reuses the earlier review's fixture and calendar isolation without adopting the redesign's screens. Mock calendar operations and notifications are simulated; backend requests are directed to unused loopback, and background sync is disabled. Production builds retain their normal service implementations. `SCREENSHOT_MODE` remains false. The preview does not use a signed-in account or personal calendars.

Simulator: Band Practice — Native UI, iPhone 17, `CD8615C1-C30E-41B6-ADB6-D416DC1F29CD`. Preview app: Availability Review, `com.keithbarney.heavybandmanager.availabilitypreview`, version 1.3.0 (8).

Build with `AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW`, the preview bundle identifier, and an isolated derived-data directory. Normal `make preflight` tests the production configuration. Additional mock tests cover saved-edit retention across scenarios, failed-save retry, preserving other members' availability, and preventing real calendar writes.

Mobbin tools were unavailable during this refinement; the current app and the user's selected navigation pattern are the design reference. The mock client initializer matches the [Supabase Swift initialization API](https://supabase.com/docs/reference/swift/initializing).

## Verification

- Mock configuration: 15 tests passed, including three new isolation/save tests. Production `make preflight`: 12 tests passed and unsigned Release build passed.
- Installed executable and debug library hashes match the final mock build, version 1.3.0 (8).
- Operated all six scenario choices in Simulator. Setup card opened the selected Availability tab; Manual → Tuesday → Save remained in the tab and displayed “Availability saved.” A failed save kept the selected days; disabling the simulated failure and retrying succeeded. Switching away and back retained Tuesday and the disabled failure toggle. Returning to Calendar overview restored its independent fixture.
- Maximum accessibility text size retained the compact review header; availability content scaled and could be scrolled. Standard text size was restored. Long band names use the current app's existing toolbar overflow menu.
- The shared Simulator app repeatedly changed foreground windows during other app reviews, and coordinate-based tab-bar taps were unavailable. The middle tab was verified through the calendar setup shortcut and scenario entry points; direct bottom-tab tapping and the Settings shortcut still need a manual check.
- Left Automatic availability visible. Screenshots: `.release/availability-tab/screenshots/calendar.png`, `availability.png`, and `accessibility.png`.

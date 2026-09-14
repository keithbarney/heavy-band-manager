# Current design with an Availability tab

Branch: `codex/current-design-availability-tab`, based on `main` at `a3a4df4`. The broader native redesign remains on `codex/native-ios-ui`.

The app keeps its existing calendar, month scrolling, availability dots, confirmed practice circles, scheduling sheets, appearance, and settings. Navigation is now Calendar · Availability · Band · Settings. The Availability tab uses the existing My Availability editor for automatic calendar-based availability or manual weekly hours. Save stays in the tab and shows the existing success toast. The calendar setup card routes to that tab. Availability controls are no longer duplicated in Settings. Changing bands recreates the editor so another band's draft cannot appear there.

The calendar observes full availability-slot changes, including updated hours with an unchanged slot count, so its cached dots refresh after editing availability.

## Isolated simulator review

The opt-in Debug condition `AVAILABILITY_TAB_PREVIEW` provides Calendar overview, Automatic availability, Settings, Band, Band member, No matching times, Setup needed, Save failure, and Long names. Every scenario owns in-memory band and calendar stores. Switching preserves saved edits; Reset affects only the selected scenario. The persistent Mock data header remains visible while navigating. Unsaved drafts reset when changing scenarios.

This reuses the earlier review's fixture and calendar isolation without adopting the redesign's screens. Mock calendar operations and notifications are simulated; backend requests are directed to unused loopback, and background sync is disabled. Production builds retain their normal service implementations. `SCREENSHOT_MODE` remains false. The preview does not use a signed-in account or personal calendars.

Simulator: Band Practice — Native UI, iPhone 17, `CD8615C1-C30E-41B6-ADB6-D416DC1F29CD`. Preview app: Availability Review, `com.keithbarney.heavybandmanager.availabilitypreview`, version 1.3.0 (8).

Build with `AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW`, the preview bundle identifier, and an isolated derived-data directory. Normal `make preflight` tests the production configuration. Additional mock tests cover saved-edit retention across scenarios, failed-save retry, preserving other members' availability, and preventing real calendar writes.

Mobbin tools were unavailable during this refinement; the current app and the user's selected navigation pattern are the design reference. The mock client initializer matches the [Supabase Swift initialization API](https://supabase.com/docs/reference/swift/initializing).

## Initial tab verification

- Mock configuration: 15 tests passed, including three new isolation/save tests. Production `make preflight`: 12 tests passed and unsigned Release build passed.
- Installed executable and debug library hashes match the final mock build, version 1.3.0 (8).
- Operated all six scenario choices in Simulator. Setup card opened the selected Availability tab; Manual → Tuesday → Save remained in the tab and displayed “Availability saved.” A failed save kept the selected days; disabling the simulated failure and retrying succeeded. Switching away and back retained Tuesday and the disabled failure toggle. Returning to Calendar overview restored its independent fixture.
- Maximum accessibility text size retained the compact review header; availability content scaled and could be scrolled. Standard text size was restored. Long band names use the current app's existing toolbar overflow menu.
- The shared Simulator app repeatedly changed foreground windows during other app reviews, and coordinate-based tab-bar taps were unavailable. The middle tab was verified through the calendar setup shortcut and scenario entry points; direct bottom-tab tapping and the Settings shortcut still need a manual check.
- Left Automatic availability visible. Screenshots: `screenshots/iphone/light/1-iphone-light-calendar.png`, `availability.png`, and `accessibility.png`.


## Settings after the tab move

Availability owns the manual/automatic method, weekly days and hours, calendars used to find free time, the daily automatic practice window, and refresh-on-open preference. Automatic mode exposes those controls directly beneath calendar connection. Source calendar choices and refresh preferences retain their immediate device-local persistence. Window edits are drafts until Save, which updates the shared availability. Invalid or empty windows and an empty source-calendar selection disable Save; invalid window writes are also rejected by the service. The existing mock save path now covers window edits and preserves other band members.

Settings removes both the availability shortcut/summary and the Automatic availability section. It keeps band-wide scheduling rules (duration and minimum members) and the confirmed-practice output calendar, plus profile, band management, appearance, notifications, and account controls. Its calendar footer now describes adding confirmed events and restoring missing events rather than discussing availability modes.

The Settings mock scenario starts with an automatic member, so review can verify that the removed controls are absent even for automatic availability. The former onboarding-only Settings preview now opens the actual Availability editor.

Settings reorganization verification: 16 mock tests and 12 production tests passed; unsigned Release build passed. Installed executable/debug-library hashes match the rebuilt preview, version 1.3.0 (8). In Simulator, Settings was scrolled from band details directly into band rules and output-calendar controls with no availability sections. The practice-calendar editor opened and returned. In Availability, Calendars to check opened, adding the mock Band Practice source changed the count from two to three, and the daily window was changed from 6–10 PM to 5–10 PM. Save succeeded; switching scenarios and returning retained the source count and saved window. Manual mode hid the automatic controls and showed weekly hours. An 11 PM–10 PM draft displayed an error and disabled Save; discarding that draft restored the saved 5–10 PM window. Calendar overview was revisited, then Settings was left visible. Screenshots: `settings-simplified.png` and `automatic-controls.png` under `.release/availability-tab/screenshots/`.

## Compact Availability screen

The mode choice now uses a large native segmented control. Connected users see one short explanation and a single group containing Calendars, Practice hours, and Refresh on open. The normal connected-status card, repeated section headings, and repeated instructions were removed. Disconnected users still see an actionable connection request. Calendar privacy and immediate-save notes sit inside calendar selection. Manual mode keeps its familiar day buttons and time wheels with less surrounding text.

Mobbin references inspected: [Beside preferred hours](https://mobbin.com/screens/7c27d1e5-e5dc-4310-a583-decd5ed6cba1) for a focused hours editor with one explanation, and [Evernote calendar selection](https://mobbin.com/flows/7929a139-755b-4f9a-9d9f-c333b85d9c47) for putting calendar details on a separate screen. These inform the hierarchy; the controls remain native SwiftUI.

Checked both automatic and manual layouts in the installed dark-mode mock preview. Calendar-source and practice-hour details opened; both automatic Save and a changed Tuesday manual schedule displayed “Availability saved.” Production preflight and both signed phone/unsigned simulator builds passed. Screenshot: `screenshots/iphone/dark/8-iphone-dark-availability-scrolled.png`. The signed normal-data build updates the existing Band Practice (L) installation on Keith’s iPhone, version 1.3.0 (8).

## Dedicated Band tab

Band now owns name/logo, the member list and member editor, invite code/sharing, organizer scheduling rules, and role-appropriate Leave/Delete Band actions. A native toolbar button opens the existing band switcher. Settings keeps profile, the practice output calendar, appearance, notifications, and account controls. The four native tabs retain the current app styling.

Band and Band member mock scenarios enter the new tab as organizer and ordinary member. Organizer name/duration/minimum-member edits are simulated in memory and retained per scenario. Production service behavior is unchanged. This extraction retains the grouped native settings pattern used in the prior Mobbin review.

Verification: 17 mock tests and 12 production tests passed; production unsigned Release preflight and signed phone build passed. In the installed mock simulator, Minimum Members was changed from three to two and retained after switching scenarios. Practice Duration and a member editor opened and returned; the band switcher opened and dismissed. The member scenario displayed a read-only band name and Leave Band, with organizer editing and scheduling controls hidden. Settings showed personal/app controls without band sections. The installed executable and debug library matched the tested build. Screenshot: `screenshots/iphone/dark/11-iphone-dark-band.png`.

Band was left visible in the dedicated Band Practice — Native UI simulator using mock data. Direct bottom-tab clicks remain unavailable through the shared Simulator computer-use coordinate bridge; scenario entry points exercised the actual tab views. The normal-data development build was installed in place and launched on Keith’s iPhone as Band Practice (L), version 1.3.0 (8).

## Large screen titles

Availability, Band, and Settings explicitly use native large navigation titles. Availability previously forced a small inline title; its root now matches the other two tabs. Detail editors keep their inline navigation titles, and the calendar retains its existing large month heading. Native scroll-to-collapse behavior is preserved.

Inspected [Crouton Settings](https://mobbin.com/screens/69e986b1-7335-474c-b3cc-ed92d463ab2b) and [CLEAR App Settings](https://mobbin.com/screens/d920fbc5-34cd-4507-8c3f-4701ee3c72c1) in Mobbin for the large, leading-aligned heading above settings content.

Production preflight passed with 12 tests and an unsigned Release build. The installed mock build matched its source artifact; Availability showed its large title before and after opening and returning from Practice hours. Screenshot: `screenshots/iphone/dark/8-iphone-dark-availability-manual.png`. Availability remains visible in the dedicated mock simulator.

## Automatic calendar introduction

The user's selected option adds a native calendar Label, the heading “Availability from your calendar,” and a short explanation of checking personal calendars during practice hours and sharing availability without event details. It replaces the previous one-line Automatic footer; Manual retains its weekly-hours explanation. Existing native controls and the prior Mobbin-informed hierarchy remain.

Production preflight passed (12 tests and unsigned Release). The installed mock artifact matched the new build. Reviewed Automatic, opened and returned from Calendars, switched to Manual and confirmed the introduction disappeared, and restored Automatic. At maximum accessibility text size the heading and paragraph wrapped, and scrolling reached the settings below. Normal text size was restored. Screenshot: `screenshots/iphone/dark/8-iphone-dark-availability-automatic.png`. Automatic remains visible on the dedicated mock simulator.

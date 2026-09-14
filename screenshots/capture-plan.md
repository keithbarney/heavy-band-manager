# Band Practice screenshot capture plan

Use `AGENTS.md` for the current five-card inventory. Order: Calendar, confirmation, personal-calendar, availability-automatic, appearance. The five-card story is now complete in all four variants; the approved iPhone Light set is preserved.

## Saved setup

- Project: `HeavyBandManager.xcodeproj`, generated from `project.yml`.
- Screenshot scheme: `HeavyBandManagerScreenshots`; ordinary `HeavyBandManager` tests stay separate.
- Debug 1.3.0 (8), bundle `com.keithbarney.heavybandmanager.local`.
- Build option: `AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW`.
- iPhone: Band Practice — App Store iPhone, iPhone 17 Pro Max, iOS 26.5, `F8B9CCD6-B79A-47B2-8553-1AAE8DFA3C80`, 1320 × 2868.
- iPad: Band Practice — App Store iPad, iPad Pro 13-inch M5, iOS 26.5, `5F3838DB-3E87-46A1-93C6-F8E84363CD5C`, 2064 × 2752.
- Data: isolated in-memory AvailabilityTabPreview, no external writes. Minor Threat, Ian/Lyle/Brian/Jeff, caption-identified local artwork. Fictional invite code THREAT. Default Night Shift remains available without --band minor-threat.
- Locale en_US, Pacific time, standard text; screenshots explicitly choose Light or Dark through `--screenshot-appearance`.

Reuse these devices; the older 11-inch iPad and iPhone 17 remain development devices and must not be erased or used as main store-size substitutes.

## Native routes and fixture

`ScreenshotTests.testCoreScreens` uses `--screenshot-mode --screenshot-story --screenshot-band=minor-threat` and an explicit appearance. It launches the verified Debug artifact, goes Home, taps the matching icon and verifies the exact bundle is foreground. This simulator also contains an older `availabilitypreview` bundle with the same “Band Practice (L)” name; never assume the first icon is the intended build. Entering from Home clears another app’s return breadcrumb.

Calendar checks green all-member and yellow partial-match semantics, all four scheduled day markers, then opens Upcoming to assert exactly four practices and returns to the grid for capture. Member hours differ: Ian 7–10 PM, Lyle 6–9 PM, Brian 7–9:30 PM, Jeff 6:30–10 PM. Minimum attendance is three of four, allowing truthful yellow dots. Four practices occupy +8/+11/+15/+17 days; all have full attendance. The unscheduled +4 day has an all-four 7–9 PM window. Tap that window’s actual time label, capture Schedule Practice confirmation, tap Schedule, reopen the date and verify Scheduled, time, location and Remove.

Automatic and Manual use the real segmented control. Band verifies all four expected photo elements and the logo. The source files stay original; native avatar viewports use documented identities. Every capture asserts absence of Mock data, Review scenario and MOCK-ONLY. Standard text only.

The helper supports `--devices`, `--appearances`, `--screens`, `--story` and `--band`, builds for the exact saved simulator, and records actual xcresult/attachment/source hashes. Outputs go to a temporary native source root, separate from maintained marketing folders. Existing native Automatic/Manual sources can be reused for composition-only changes with their original provenance.

Apple Calendar is a separately staged simulator-local illustration using `scripts/BandCalendarDemo.swift --minor-threat`; iPhone Light preserves its approved card. The other variants use the same three fictional rehearsals; iPad displays the agenda beside Month view. Never report it as proof of app synchronization or real band activity.

## Composition and validation

Use `scripts/compose-benefits.py` with `--variants` and `--screens`; commands are in the README. Use one full-width Automatic screen for both availability methods, with the Manual tab visible. Headline: “Auto-sync your availability. / Or set it manually.” A separate Manual card is excluded. Only Appearance uses `render-pair-marketing.swift`: Band Light behind, Dark in front, without labels and with matching outer margins.

| Device | Canvas | SF Semibold size/top/line height | Screen width/top | Frame/radius |
| --- | --- | --- | --- | --- |
| iPhone | 1320 × 2868 | 120 / 210 / 136 | 1100 / 700 | 14 / 108 |
| iPad | 2064 × 2752 | 164 / 160 / 180 | 1720 / 650 | 22 / 64 |

The combined availability headline uses 102px on iPhone; other cards retain 120px. This keeps its approved two-line wording inside the standard safe margins.

Inspect every changed native capture and all composed cards, including headline fit, both dot colors, four scheduled practices, clearer portraits and readable availability explanations. Reject debug controls, unintended placeholders, wrong appearance and return breadcrumbs. Publish only after visual-review hashes and file validation pass. Keep one current contact sheet, validation report and manifest per set. Apple pixel sizes were checked September 12, 2026. Screenshot capture does not authorize upload.

The personal-calendar route selects only Band Practice, checks three events, and handles iPad calendar/sidebar toggles, refreshed queries after changing selections, and a restored event popover. On iPad it selects Month, returns to Today and opens the agenda. Capture one appearance at a time; the runner sets system appearance and relaunches Calendar. September 13 runtime: iOS 26.5 (23F77), resolved from simulator inventory for current exports.

# Widgets and practice location editing

## Implementation

- `BandPracticeWidget` supplies Small, Medium, and Large Home Screen widgets. New widgets default to **All bands**, while existing single-band selections remain supported. Small shows the next practice across all bands. Medium shows two practices for each of up to two bands; Large shows three each for two bands, or two each for up to three bands. Band sections sort by their next practice, with practices chronological within each section. Accessibility text reduces the displayed groups/rows.
- Medium and Large link to **All Band Practices**, a native grouped list containing every band's upcoming practices, including empty/unloaded bands and stale-data notices. This screen is also available from Calendar's upcoming-practices list. It refreshes from the existing app-owned cache/sync service and opens a selected practice's band and day.
- Single-band widgets still show up to one, three, or six practices, reducing rows for accessibility text and reserving room for stale-data notices.
- `Shared/PracticeWidgetData.swift` is the credential-free data contract and date/timeline logic shared with the app. Widget dates follow the app's local wall-clock practice dates; the backend has no band timezone field.
- `Shared/PracticeWidgetConfiguration.swift` supplies a native dynamic-options picker with band names and stable band IDs. Each widget keeps its configured band; a removed band shows an unavailable state instead of switching bands. Both app and extension include the configuration intent.
- `PracticeWidgetSync` publishes authoritative data, fetches upcoming practices across joined bands, handles confirmed local mutations, and invalidates data on account changes or membership removal. Calendar browsing does not publish filtered results. Background practice refresh is independent of calendar permissions and manual/automatic availability.
- The extension reads the App Group cache. It does not make authenticated backend requests or receive APNs pushes. Other members' changes are reflected after an app refresh succeeds. After 24 hours without a complete successful band fetch, the widget prompts for refresh.
- Widget links carry band/practice IDs. The app validates membership, loads the current practice, selects Calendar, and opens its day. Missing/cancelled practices show an unavailable message.
- Leaders can edit/clear the default location in Band → Scheduling, and a scheduled practice's location via Practice options → Edit Location. The editor supports manual text and place search, with Save/Cancel and retryable errors. Nonleaders see the default as read-only.
- Default changes affect newly scheduled practices. Individual edits affect only that practice. A scheduling-time override remains outside this implementation.
- EventKit reconciliation now updates an existing event's title, location, and dates while preserving its identity, calendar, notes, and alarms. It also clears removed locations. A successful backend edit with failed calendar sync produces a separate warning.

## Build configuration

`project.yml` remains the source of truth. The app embeds the extension; both use the same version/build.

| Configuration | App | Extension | App Group |
| --- | --- | --- | --- |
| Debug | `com.keithbarney.heavybandmanager.local` | `com.keithbarney.heavybandmanager.local.widgets` | `group.com.keithbarney.heavybandmanager.local` |
| Release | `com.keithbarney.heavybandmanager` | `com.keithbarney.heavybandmanager.widgets` | `group.com.keithbarney.heavybandmanager` |

App Group provisioning and extension signing must be available when making a signed device/Store build. Simulator review uses ad-hoc signing so the system creates the shared container. `make preflight` still uses unsigned builds; it now overrides `BAND_APP_BUNDLE_IDENTIFIER` instead of assigning the same bundle identifier to both the app and its extension.

## Isolated review

Build with `AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW` and launch with `--widget-review`. This uses the existing Debug Simulator mock services and visible review header, adds six Night Shift practices and three Sunday Static practices, and shares only `practices-mock.json` with a widget compiled in the same review configuration. Existing screenshots/story runs keep their original fixture counts. Stable mock practice IDs allow widget links across app launches; saved practice locations are restored from the mock widget snapshot.

Reuse the project-owned iPhone `F8B9CCD6-B79A-47B2-8553-1AAE8DFA3C80` and iPad `5F3838DB-3E87-46A1-93C6-F8E84363CD5C`. Personal/Release cache data is separate from mock cache data. Production network and calendar writes remain blocked in the review build.

Functional UI regression tests are in `HeavyBandManagerScreenshotTests/PracticeFeatureTests.swift`; they require the review compilation condition. Unit coverage includes same-day ordering, ongoing/ended practices, daylight-saving midnight boundaries, stale timelines, cache clearing, link validation, location permissions/failure/retry, independent defaults/overrides, and EventKit field reconciliation.

## Design references

The [Outlook widget reference](https://mobbin.com/screens/25ccb821-186c-4f31-bbed-f434469e987c) informed the date-and-agenda hierarchy. The [Alta editing flow](https://mobbin.com/flows/b3c445e8-2ec6-4f84-be6e-e3eeafeba906) was reviewed for explicit editing and Save behavior; this app uses its existing native form and toolbar conventions.

The band picker uses Apple's [dynamic option items](https://developer.apple.com/documentation/appintents/intentitem) to separate each stable ID from its displayed name. This avoids the cross-process AppEntity registration failure observed during native widget configuration testing.

The all-bands update also consulted [Outlook's calendar/list view flow](https://mobbin.com/flows/99c7f72e-d103-460f-b6ad-fa39d17229fe): a compact widget agenda opens a fuller native list with clear section headings. Here the sections identify bands so the next few practices from each remain distinguishable.

## Validation record

The review artifact is **1.3.0 (8)**, Debug, `com.keithbarney.heavybandmanager.local`, built from commit `2589782` plus the uncommitted implementation in this checkout. Both saved devices run iOS 26.5. UI review uses the fictional Night Shift / Sunday Static dataset, with the mock review header visible in the app.

- Required `make preflight`: passed, including 20 production-configuration unit tests (zero failures or skips) and an unsigned Release build of the app and widget. Results: `.release/widgets/preflight/DerivedData/Logs/Test/Test-HeavyBandManager-2026.09.14_18-06-51--0700.xcresult`.
- Review-configuration units: 25 passed, including leader/member permissions, failure/retry, independent default and individual locations, dates, cache, routes, and event fields. Results: `.release/widgets/ReviewTests2.xcresult`.
- Native location walkthrough passed on iPhone and iPad: save default, reopen, cancel an attempted clear, edit one practice, and clear that practice's location. Results: `.release/widgets/UITests2.xcresult` and the location test in `.release/widgets/IPadUITests.xcresult`.
- Real EventKit integration: passed with no skips. Created a uniquely named, Simulator-local test calendar, changed and cleared an event's location, and verified the saved event through fresh event stores. The event retained its identity, notes, and alarm; no duplicate remained. The test removed its own calendar afterward. Results: `.release/widgets/CalendarIntegration.xcresult` and final preflight.

- Live iPhone widgets: Small (one practice), Medium (three), and Large (six) opened the expected practice day. Large also passed a cold app launch. The `testInstalledWidgetLinksAndConfiguration` case passed in `.release/widgets/VerifiedIPhoneWidgets.xcresult`; the separate configuration case in that earlier bundle failed and was investigated independently.
- Live iPad widgets: the gallery-addition walkthrough added Medium and Large, verified three/six rows and exact practice destinations, including a cold launch. Results: `.release/widgets/IPadLiveGalleryWidgets.xcresult` (one test passed). The Small link passed at accessibility text size in `.release/widgets/IPadAccessibleWidget.xcresult` (one test passed); its start/end times remained readable. Standard text size was restored afterward.
- Final configuration implementation on iPad: both `testMediumAndLargeWidgetsFromGallery` and `testSmallWidgetLink` passed in `.release/widgets/FinalIPadOptionsWidgets.xcresult` (two tests, zero failures), exercising all three live sizes again after the configuration change.
- Final native band configuration on iPhone: passed in `.release/widgets/NamedBandConfiguration.xcresult` (one test, zero failures). Selected Night Shift and then Sunday Static in Edit Widget, verified Sunday Static on the live widget, relaunched the app on Night Shift, confirmed the widget retained Sunday Static, and tapped through to September 16, 6–8 PM at Eastside Studio. The earlier AppEntity resolution failure is eliminated by storing the band's stable ID through the native dynamic-options picker.
- Final screenshots are in `.release/widgets/final-ipad-options-attachments/` and `.release/widgets/final-band-configuration-attachments/`. The final iPad Home Screen and exact practice destination were visually inspected. The maintained marketing screenshots and the pre-existing `screenshots/manifest.json` change were preserved.
- Reviewed Home Screen evidence: `.release/widgets/ipad-live-attachments/814327DF-D4E3-4E8B-A3CF-7B61FBB5EC2B.png` shows all three live widget sizes. Gallery samples are separate from this evidence.

### Delivery limits

Simulator checks do not establish cross-device delivery or background refresh timing. The widget uses app-owned refresh and a shared cache, so another member's change can remain cached until the app next refreshes successfully. Release/Store provisioning remains separate from the development provisioning verified below; no App Store upload was requested or performed.

### Physical iPhone delivery — September 14, 2026

At Keith's request, built and installed **1.3.0 (8)** in place over the existing **Band Practice (L)** installation on **Keith’s iPhone 16 Pro**, running iOS 27.0. Bundle identifier: `com.keithbarney.heavybandmanager.local`; Debug configuration with both preview compilation conditions empty. Source: `2589782` plus this checkout's uncommitted widget/location implementation. Existing app data was preserved; no mock data was enabled.

- Signed app and embedded widget build passed using the existing Apple Development identity and automatic provisioning.
- Verified both signatures, matching `group.com.keithbarney.heavybandmanager.local` entitlements in the signatures and provisioning profiles, and inclusion of the target phone in both profiles.
- `devicectl` confirmed successful installation and launch, then reported installed version 1.3.0, build 8. Evidence: `.release/widgets/phone-install.json`, `phone-launch.json`, and `phone-installed-apps.json`.
- Installed artifact: `.release/widgets/PhoneDerivedData/Build/Products/Debug-iphoneos/HeavyBandManager.app`, including `PlugIns/BandPracticeWidget.appex`.
- The physical phone's Home Screen widget UI and personal practice/calendar contents were not inspected. Native functional widget and calendar tests remain the Simulator results above.

### All-bands update and phone delivery — September 14, 2026

- Final required `make preflight` passed: 23 production-configuration tests, no failures or skips, followed by the unsigned Release app/widget build. Results: `.release/widgets/preflight/DerivedData/Logs/Test/Test-HeavyBandManager-2026.09.14_22-48-55--0700.xcresult`. New unit coverage verifies fair per-band allocation, chronological ordering and empty bands, the explicit All bands default, and mutually exclusive list/practice navigation.
- iPhone native Home Screen walkthrough passed in `.release/widgets/AllBandsIPhone.xcresult`: added Medium and Large widgets, verified both bands, opened Sunday Static's exact practice, and opened the full grouped schedule through a cold app launch. One test, zero failures.
- iPad native walkthrough passed in `.release/widgets/AllBandsIPad.xcresult`: all three widget sizes, secondary-band practice destinations, full schedule from the widget and Calendar, and return from practice details. Three tests, zero failures.
- iPhone accessibility-large walkthrough passed in `.release/widgets/AllBandsAccessible2.xcresult`: reduced Medium/Large layouts and the full schedule remain readable. Standard text size was restored. The initial accessibility attempt assumed the current Home Screen page and failed to find its widget; the corrected test locates the installed widget across Home Screen pages. One final test, zero failures.
- Visually reviewed actual Home Screen captures in `.release/widgets/all-bands-iphone-attachments/` and `.release/widgets/all-bands-ipad-attachments/`, plus the final large-text widget and schedule captures in `.release/widgets/all-bands-accessible2-attachments/`. The full schedule uses primary/secondary text colors and wrapping locations. Maintained marketing screenshots were not changed.
- Rebuilt the normal signed Debug app and widget with preview conditions empty, verified both signatures, then installed and launched the all-bands update on Keith's iPhone 16 Pro. `devicectl` confirmed version **1.3.0 (8)**. Evidence: `.release/widgets/all-bands-phone-install.json`, `all-bands-phone-launch.json`, and `all-bands-phone-apps.json`. Installation updated the existing local app in place.
- New widgets default to All bands. Existing widgets retain their saved band; select **Edit Widget → Band → All bands** to change them. The physical phone's personal schedule and Home Screen widget UI were not inspected; functional evidence is from the isolated Simulator walkthroughs above.

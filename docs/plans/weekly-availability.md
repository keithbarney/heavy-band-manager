# Weekly availability implementation plan

Status: core implementation complete; date exceptions, atomic sync RPCs, and full recurrence projection are follow-up hardening work.

Let every band member share usable rehearsal times without maintaining a personal calendar. Members choose either recurring weekly hours or calendar-based availability. Both feed the band's existing overlap finder, so the organizer can schedule a practice for members using different methods.

**Product decisions**

- Reuse one **My availability** flow in onboarding and Settings.
- Offer **Automatic** and **Manual**. Onboarding starts with Automatic selected; each member can choose Manual instead.
- Weekly hours repeat until edited. Selected hours are times the app may suggest; they do not represent attendance confirmation for an individual practice.
- Availability belongs to the current band membership, matching the existing practice-window model. Label the editor with the band name.
- Support one time range per selected weekday, with 30-minute increments and a way to apply the same hours to several days. Additional daily ranges and overnight ranges are later improvements.
- Include a full-day **Unavailable this day** exception and an undo action. Exceptions do not change the recurring week.
- Keep calendar-based availability and adding scheduled practices to a device calendar as separate choices.
- Preserve existing calendar users' setup. They can adopt weekly hours from Settings.
- This release covers these availability flows. The proposed home-screen recommendations, polling, attendance responses, and combined weekly-hours-plus-calendar mode are separate work.

**1. Build the shared availability editor**

Create `MyAvailabilityView` and a reusable weekly-hours editor using the app's existing SwiftUI styling and native controls.

The entry screen asks **How would you like to share your availability?**

| Choice | Supporting text | Next step |
| --- | --- | --- |
| Choose my usual times | Pick the days and times you can usually practice. | Weekly editor |
| Use my calendar | Find openings around your calendar events. | Explain calendar access, request it if needed, review calendar sources and rehearsal hours |

The weekly editor starts with no assumed availability. Members select days, enter a start and end time, and can reuse those hours across selected days. Show **Repeats every week. You can change individual dates later.** Finish with a readable summary and **Save availability**.

Require at least one valid range for initial weekly setup. For an existing schedule, provide an explicit **I'm unavailable for now** action so clearing all days can be intentional. Distinguish this state from someone who has not completed setup.

Keep edits local until Save. Cancel leaves the active method and shared availability intact. Keep the form open with a useful error and retry action if saving fails; show success only after the server accepts the change.

**2. Add the flow to onboarding and Settings**

For new members, show availability setup after band/profile setup. Support both create and join, including additional bands created or joined through the band picker. Persist whether setup is complete so closing and reopening the app resumes the correct step.

Creating or joining a membership must not bypass the remaining profile and availability steps. Availability is required during onboarding, with no skip option. Show **Get Started** at the bottom, enabled only after calendar access is connected for either method; Manual also requires valid days and hours. Settings continues to use **Save**.

In Settings, place **My availability** outside the calendar-permission condition. Show the selected method, a compact summary such as **Tue, Thu · 7–10 PM**, and **Change**. Keep band practice-duration and attendance settings accessible regardless of the organizer's availability method.

Switching behavior:

| Action | Expected result |
| Calendar → weekly | Review or enter weekly hours, then save the hours and method together. Retain the previous calendar configuration. |
| Weekly → calendar | Obtain access, review sources and rehearsal hours, and complete an initial sync before switching. Retain the weekly template for future reuse. |
| Cancel or save failure | Continue using the previous method and availability. |
| Calendar permission denied | Explain that both methods need access to add scheduled practices. Offer Settings to reconnect. Do not treat an unreadable calendar as an empty, fully free calendar. |
| Calendar permission later revoked | Ask the member to reconnect so scheduled practices can be added. Retain their availability method and weekly hours. |

Require calendar connection for both availability methods. Scheduled practices are added automatically, with no opt-out toggle. Manual uses weekly hours rather than calendar events to determine availability. Notification permission must also work without calendar permission and respect a previous dismissal.

**3. Persist recurring rules and safe source changes**

Add an additive Supabase migration and Swift models for:

| Data | Purpose |
| --- | --- |
| Availability method and setup state on the membership | Identify calendar, weekly, or unfinished setup; distinguish known unavailability from missing data. |
| Weekly rules keyed by member and weekday | Store the recurring start/end times independently of dated slots. |
| Date exceptions keyed by member and date | Exclude individual rehearsal dates without rewriting the recurring week. |
| Availability revision and calendar-refresh metadata | Reject stale writes and identify a calendar source needing attention. |

Keep `availability_slots` as the dated representation consumed by the overlap engine and existing clients. Weekly rules are the source of truth for weekly members; their dated rows are derived data.

Add an authenticated save RPC that validates ownership and ranges, checks the expected revision, saves the method/rules/exceptions, and replaces the applicable dated rows in one transaction. Preserve the last saved inactive template. Calendar-to-weekly switching must replace old calendar rows as part of that same successful transaction.

Add a band availability-loading RPC that ensures weekly members' dated rows cover the requested range before returning the band's slots. Expand on the server from saved rules, regardless of whether those members have recently opened the app. Cover the full six-month calendar viewport, use consistent exclusive end bounds, and only change rows when their content changes to avoid realtime refresh loops.

Existing users and legacy create/join calls retain calendar behavior. New app create/join paths explicitly record unfinished setup. Preserve the trusted invite/create RPC protections and existing membership column grants; new fields must be writable only through the intended authorized path.

Database rules must prevent direct or stale calendar sync writes from modifying weekly members' derived slots, including writes from an older app version. Band members may trigger deterministic expansion from saved rules through the loading RPC but may edit only their own rules and exceptions. Validate that `member_id` and `band_id` belong together.

Retain the app's existing local rehearsal-date/time convention for this release. Expand by calendar dates and weekdays, so a 7 PM weekly rule remains 7 PM across daylight-saving changes. General scheduling across different time zones is outside this feature; do not introduce timezone conversions into only one availability method.

**4. Integrate both methods with sync and overlap**

Route availability loading through the new service/RPC while retaining the `AvailabilitySlot` input to `OverlapEngine`. Calendar members continue to derive openings from selected calendars within their rehearsal hours. Weekly members derive openings from their saved rules and date exceptions.

Update foreground auto-sync, manual resync, and background sync to check each membership's active method. A device can have calendar access for practice events while its member uses weekly availability. That access must never cause calendar reads to replace weekly hours.

Replace calendar sync's separate delete/insert requests with an atomic, revision-checked replacement RPC. A sync started before a method change must be rejected after the change. Apply one shared scheduling transformation for foreground/background paths to avoid their current duplicated logic diverging.

Make sync throttling specific to the membership/configuration, and refresh immediately after a saved rule change or source switch. Protect asynchronous loads against a band switch while a request is in flight.

Refresh calendar dots and day details when the contents of slots or member setup state change, even when the number of slots stays the same. The current count-only observation can miss a moved time range. Provide **Availability not set** or **Calendar needs attention** where applicable instead of always interpreting an empty slot list as **Not available**.

Subtract already scheduled practices in other bands from weekly suggestions using shared practice records, without requiring device-calendar access. This keeps the new source useful for existing multi-band users. Preserve scheduled practices when a member changes their availability method.

**5. Add date exceptions and separate practice-calendar preferences**

In `DayDetailSheet`, let a weekly member mark their own date **Unavailable this day**. Show the exception and **Use my usual hours** to undo it. Save and recompute shared overlap immediately; do not cancel an existing practice or imply the organizer has been notified of an attendance change.

Provide an independent **Add practices to my calendar** preference in the calendar section. Keep its behavior separate from calendar availability and from the weekly setup requirement. Honor it in scheduling, reconciliation, and permission-change handlers. Reuse the existing practice-event registry and respect the calendar permission level needed by the existing integration.

Changing availability method must not delete existing practice events. Turning off future calendar additions should explain that existing events remain; bulk removal is separate work. Previously connected users retain their current event behavior, and new weekly members are not prompted for calendar access unless they choose calendar additions.

**Implementation order and affected code**

| Order | Work | Main locations |
| --- | --- | --- |
| 1 | Schema, ownership rules, atomic RPCs, recurrence projection, compatibility tests | `supabase/migrations/`, `supabase/tests/database/` |
| 2 | Models, source-aware availability loading, safe foreground/background sync | `Models/Band.swift`, new availability models/service, `Services/BandManager.swift`, `Services/CalendarManager.swift`, `Services/BackgroundSyncManager.swift` |
| 3 | Shared editor, onboarding coordination, Settings entry, permission behavior | New availability views, `Views/OnboardingView.swift`, `Views/BandGate.swift`, `Views/BandPickerSheet.swift`, `Views/BandTabs.swift`, `Views/SettingsView.swift` |
| 4 | Exceptions, reliable overlap refresh, independent practice-calendar preference | `Views/DayDetailSheet.swift`, `Views/CalendarMonthView.swift`, `BandManagerApp.swift`, calendar sync/event paths |
| 5 | End-to-end verification, simulator screenshots, screen mapping and release notes | `HeavyBandManagerTests/`, `.github/workflows/`, `figma-sync.md`, `marketing/` |

Swift paths in this table are relative to `HeavyBandManager/`. Use `project.yml` for any project configuration changes and regenerate with XcodeGen. Do not edit the generated Xcode project.

**Acceptance and verification**

- A new member can create/join a band, connect their calendar, and choose either weekly hours or automatic availability. Both methods add scheduled practices to the calendar.
- Weekly and calendar members appear together in the existing month and day views; only the organizer retains scheduling authority.
- A recurring schedule remains usable beyond its initial generated horizon when another member loads the band, even if its owner has not reopened the app.
- Updating hours changes suggestions even when the slot count is unchanged. Exceptions remove only their date, and undo restores that date's usual hours.
- Source switches survive relaunch; cancelling and failed saves preserve the old configuration. Offline edits are not shown as shared until saved successfully.
- Foreground, background, and older-client sync attempts cannot overwrite weekly hours. Concurrent saves return a conflict instead of silently replacing newer choices.
- Permission denial/revocation does not publish false availability. Manual onboarding requires calendar permission; reconnecting after revocation preserves the chosen weekly hours.
- Adding practice events works independently where authorized, existing events survive source changes, and registry reconciliation does not duplicate events.
- Multi-band settings remain isolated, while scheduled rehearsals in another band block conflicting weekly suggestions.
- Test weekly expansion across month/year boundaries and daylight-saving transitions, invalid/empty ranges, source changes, exceptions, authorization, concurrent sync, and realtime updates.
- Run `supabase db start`, the existing invite-security database tests, the new availability database tests, and the CI database lint command. Update CI to include the new test suite.
- Run `make preflight` for XCTest and the unsigned Release build. Visually inspect onboarding and Settings on the simulator with large text, VoiceOver labels, and light/dark appearance. Capture screenshots for the eventual UI PR and keep `SCREENSHOT_MODE = false`.

Roll out the additive backend support before enabling the new client flow. Verify older clients can still read generated dated rows and that their calendar writes remain compatible for calendar members. Do not enable weekly setup until those compatibility and race tests pass. Production migration deployment and App Store upload are separate release actions.

For the first usability check, have a bandmate set two recurring rehearsal days without assistance, then ask the organizer to find a practice using a mix of weekly and calendar members. Observe whether either person needs to send a message to understand or correct the displayed availability.

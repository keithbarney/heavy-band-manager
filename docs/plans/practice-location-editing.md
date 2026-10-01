# Practice location editing — investigation

Implementation and validation are tracked in [Widgets and practice location editing](../widget-and-location-review.md). The investigation below records the original findings and proposal.

September 14, 2026. Source reviewed: `2589782`. Findings are from the current checkout; no installed-app walkthrough or live backend verification was performed.

## Current behavior

**Users cannot currently change a scheduled practice's location through the app. There is also no location editor for an existing band's default location.**

| Action | Current support | Evidence |
| --- | --- | --- |
| Choose a location while creating a band | Yes, optional, in onboarding and Create Band | `Views/OnboardingView.swift:372`, `Views/BandPickerSheet.swift:188` call `updatePracticeLocation`. |
| Change an existing band's default location | Service exists, but no settings control | `Services/BandManager.swift:952` updates `bands.default_practice_location`; `Views/BandSettingsView.swift` has no location row. |
| Choose a different location when scheduling | No | `Views/DayDetailSheet.swift:82` confirms the time and passes the band's default location directly. |
| Edit a scheduled practice's location | No | `Views/DayDetailSheet.swift:164` displays the location and offers leaders only Remove. No practice-update service was found. |
| Change locations as an ordinary member | No current editing path | Existing service checks `isLeader`; checked-in practice-update policy requires `is_band_leader(band_id)`. |

`updatePracticeLocation` is misleadingly broad in name: it updates the **band default**, not an existing practice. A scheduled practice stores its own copy of `location`. Changing the default alone would affect future scheduling and leave previously scheduled practices unchanged.

The location search shows a place name and address but saves only `result.title` (`Views/LocationSearchView.swift:19`). It has no manual-entry or clear-location action. A rehearsal room nickname or a specific address may therefore need a more flexible editor.

## Calendar synchronization gap

`Services/CalendarManager.swift:339` returns immediately when it finds an existing local practice event. It assigns `event.location` only when creating a new event. Consequently, even if a practice location were updated in the backend, the current reconciliation path would leave an existing Apple Calendar event at its old location.

The app already reacts to Realtime practice updates and compares location changes (`Services/BandManager.swift:755`). It reloads the practice list and invokes calendar reconciliation. This is a useful integration point, but reconciliation must actually update existing event fields. These callbacks do not establish immediate delivery to every member's device while their app is closed.

## Recommended change

Keith approved leader-only editing of the band's default practice location and an individual practice's location, together with calendar synchronization fixes, during the September 14 review. This records the accepted direction; implementation has not started. The scheduling-time override below remains an additional proposal.

1. **Band → Scheduling → Default Practice Location.** Leaders can edit or clear it; members can view it. Explain that it applies to newly scheduled practices.
2. **Practice day → Scheduled practice → Edit Location.** Leaders can change this practice only. Start with its stored location, offer place search and manual text, and allow clearing it. Keep the band default unchanged.
3. **Schedule Practice confirmation.** Prefill the default and allow an override before saving, using a native sheet/form if the confirmation alert becomes too limited.
4. **Save reliably.** Update the practice by both practice ID and band ID, preserve leader authorization, return success/failure to the UI, and show confirmation only after the write succeeds. Existing location strings can support a basic editor without a schema migration; structured coordinates/addresses would be separate scope.
5. **Update calendar events and the future widget.** Reuse each local event's identity while reconciling its location, including clearing an old location. Refresh the app data and shared widget snapshot. Surface calendar-sync failures separately from a successful practice save.

Keep the default and individual-practice actions explicit. A bulk “apply to existing practices” action can be considered separately because some rehearsals may intentionally use different venues.

Before reusing `updatePracticeLocation` in mock review, add the isolated mock branch: this method currently has no `AVAILABILITY_TAB_PREVIEW` guard, unlike several nearby edit methods. New location editing must simulate backend/calendar writes in review mode. Also replace its current print-only error handling with a result the editor can display.

## Validation when implemented

- Leader can save, clear, cancel, and retry a failed edit; nonleaders cannot write.
- Default changes affect new practices; editing one practice preserves other practices and the band default.
- Reloading/relaunching preserves the saved value; the calendar list and day sheet agree.
- An existing local calendar event changes location without duplication; clearing the location clears EventKit's value too.
- A second authorized test member sees the updated location after refresh, with calendar permissions both granted and denied.
- Search, manual entry, long addresses, mock isolation, and widget refresh are exercised on the saved simulators; run `make preflight` for the implementation.

No production data, app code, or calendar events were changed during this investigation.

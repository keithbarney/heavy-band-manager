# Feedback and user research

Adapted from TV & Movie Calendar Sync on September 15, 2026. Entry point: **Settings → Feedback & Support**.

## User flow

- Send Feedback → choose a category → write a message → review the email preview → Submit opens Mail for the user to review and send. If Mail is unavailable, offer Copy Feedback and Copy Email Address, with an explicit copied/not-sent message.
- Band → Report a Scheduling Problem; Settings → Report a Sync Problem; failed availability save → Report a Scheduling Problem.
- Context (team or band name) is excluded by default and can be included explicitly. App version/build, OS version, permission states, and static entry-point name are optional. No calendar contents, membership lists, account tokens, logs, or automatic screenshots are attached.
- Cancel asks before discarding a written feedback message. Cancelled, saved, and failed mail attempts retain the message; only Mail's queued result clears it. Queued is not proof of delivery.
- The Three-Question Survey asks how the app is used, what is frustrating/missing, and which change would help most. Only the first multiple-choice answer is required, including getting-started and not-working options. Written answers and a 15-minute conversation opt-in are optional. Turning off the opt-in erases the reply address.
- Survey answers save locally and survive closing/relaunching. Settings always provides access and draft deletion. No analytics or backend submission is introduced.

All emails use `keithbarneydesign@gmail.com`, with **Band Practice** in the subject. No email is sent automatically.

## Invitations

A nonmodal invitation appears on the main screen after at least two foreground sessions and three days of use. Not Now, closing the survey, copying answers, and saving mail defer invitations for 30 days. Don’t Ask Again persists an opt-out. Mail's queued result marks the survey complete and clears the local draft; cancelled/failed/saved/copied mail never marks completion. Preferences and answers use the app's own local defaults, separately from other apps.

## Mock review and tests

Use the existing isolated mock setup: `AVAILABILITY_TAB_PREVIEW_CONDITION=AVAILABILITY_TAB_PREVIEW`, saved iPhone `F8B9CCD6-B79A-47B2-8553-1AAE8DFA3C80`, and the iPad documented in AGENTS.md. Mock sheets retain a Mock data label, block Mail composition, and keep survey data in a separate defaults suite. The Debug-only `-feedback-reset` clears only that mock survey suite; `-feedback-invitation` makes its invitation eligible for native UI testing. These flags do nothing to production/personal survey state.

`FeedbackTests` covers data exclusion, whitespace validation, interview consent, mail outcomes, invitation boundaries, session counting, draft persistence, and opt-out. `FeedbackFlowTests` in the existing UI test target operates native controls for contextual consent, copy fallback, discard, saved-draft reopening, and invitation deferral. Evidence lives in `/private/tmp/feedback-rollout`; these are development review captures, not App Store marketing assets.

## Design references

The existing TV & Movie implementation supplies the behavior. Reviewed Mobbin previews: [Amie feedback](https://mobbin.com/flows/07771b1c-824a-49b5-9a7c-24ec906866aa) supports a clear Settings entry and focused message form; [Copilot feedback](https://mobbin.com/flows/a6a116fd-ed4e-4bfd-9255-94fc229c2c7a) supports category selection and an explicit inclusion control. This implementation uses native SwiftUI Forms, Pickers, Toggles, sheets, and the system Mail composer with a visible preview.

## Validation — September 15, 2026

- 26 unit tests passed, including consent, privacy, mail outcome, persistence, and invitation-boundary tests.
- Four native journeys passed on both saved iPhone and iPad devices: contextual opt-in, feedback/copy/discard, invitation deferral, and survey editing/persistence/copy. Targeted retries resolved a recycled-list sheet presentation issue, per-field survey focus on iPad, and UI test scrolling/dismissal timing.
- Debug app and widget builds passed; unsigned Release app and widget builds passed. Native review covers dark iPhone and light/dark iPad layouts using isolated mock data.
- Local Debug version label remains 1.3.2 (10), with this additional uncommitted feedback implementation. These local changes are separate from the already submitted App Store binary with that version number; no new upload was performed for this feature request.
- No real email was sent. Mail composer delivery requires a Mail-configured physical device; Simulator verification covers the honest copy fallback.
- Test bundles and native review screenshots: `/private/tmp/feedback-rollout`. Production code stays independent of other checkouts; shared behavior is documented here and in AGENTS.md.

The final survey introduction uses standard row insets to avoid clipping against native rounded corners. Cross-device validation index: `/private/tmp/feedback-rollout/validation.json`.

## Follow-up review — September 15, 2026

Availability error reports now use a stable presenter local to the availability screen, so they can open over an existing modal without discarding unsaved choices. The root keeps ownership of survey progress. The Save failure mock scenario includes “Review availability in sheet” to reproduce the nested route without external writes. The focused native iPhone regression verified the scheduling category/source and preserved an edited day selection after dismissing feedback; the root survey invitation/deferral regression also passed. Evidence: `/private/tmp/feedback-rollout/band-feedback-modal-visible.xcresult` and the passing invitation test in `band-feedback-review.xcresult`. No additional feedback/privacy findings in Sports. Actual Mail delivery still requires a configured physical device.

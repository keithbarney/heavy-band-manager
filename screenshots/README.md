# Band Practice marketing screenshots

Current selection on iPhone/iPad in Light/Dark: five cards covering automatic time matching, confirming practice, calendar delivery, automatic or manual availability, and Light/Dark appearance. The current core inventory and headlines are in `AGENTS.md`. All four variants are complete; the approved iPhone Light set retains its original capture records.

The current fixture is Minor Threat’s original four members with local photos and logo. [Artwork sources and identification](../Fixtures/MinorThreat/SOURCES.md). Availability, invitations, locations and practices are fictional. Use the saved project simulators and isolated in-memory mock mode; no external writes from the app. Native sizes are 1320 × 2868 for iPhone and 2064 × 2752 for iPad.

## Capture and compose

```sh
./scripts/capture-screenshots.sh --story --band minor-threat --devices iphone,ipad --appearances light --screens calendar,confirmation,availability-automatic,band --output-root /tmp/band-minor-threat-native
./scripts/capture-screenshots.sh --story --band minor-threat --devices iphone,ipad --appearances dark --screens calendar,confirmation,availability-automatic,band --output-root /tmp/band-minor-threat-native
```

The calendar overview shows yellow/green availability dots and exactly four scheduled practices. One full-width Automatic screen communicates calendar syncing and manual availability; its Manual tab stays visible. Native Band Light/Dark sources feed the overlapping appearance card, Dark in front without labels. Brian and Jeff use the clearer caption-identified 1983 porch photograph.

The Apple Calendar illustration uses `scripts/BandCalendarDemo.swift`, a standalone Simulator-only helper. `--minor-threat` updates the helper-owned fictional rehearsals in the local Band Practice calendar. Capture the native list using `--screens personal-calendar --appearances light --band minor-threat`. It illustrates calendar delivery; it is not a cross-device sync test.

For this headline revision, preserve the other four cards and use `--screens` on the composer:

```sh
/Users/keithbarney/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 scripts/compose-benefits.py \
  --source-root /tmp/band-minor-threat-native --stage /tmp/band-availability-review --variants iphone/light \
  --screens availability-automatic
```

Omit the composer’s screen selector for a future full five-card refresh. Verify current native inputs first; never use composed marketing cards as inputs. iPhone headlines use SF Semibold 120px with a two-line maximum; the combined availability card uses 102px to fit its approved wording within the same safe margins.

Inspect the native captures and all five staged cards, then record `visual-review.json` with `passed: true` and a `hashes` dictionary of every staged output path relative to the stage. Repeat the composition command with `--publish`. It verifies the inspection hashes, replaces selected images, retires obsolete files only in that variant, and updates the contact sheet/validation/manifest. Unselected images retain their exact bytes and per-image provenance. The older `compose-marketing.py` provides shared helpers and the previous set’s definition; `compose-benefits.py` is the current entry point.

Band Practice 1.3.1 contains the verified App Store screenshot upload; build upload and App Store submission remain separate.

Apple Calendar uses a three-event agenda on iPhone and the same agenda beside Month view on iPad. The helper now sets the requested system appearance, relaunches Calendar, and handles the iPad sidebar and restored event popover. Its runtime build is resolved from the exact simulator. Capture personal-calendar separately in each appearance.

App Store upload was requested September 13. Both current versions are live and locked. Proposed drafts Sports 1.1.1 and Band Practice 1.3.1 await Keith’s version-number confirmation; no remote screenshot mutation has occurred.

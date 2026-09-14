# Minor Threat review artwork

Requested by Keith for the Band Practice iPhone Light marketing iteration on September 13, 2026. Uses the original four-member lineup: Ian MacKaye (vocals), Lyle Preslar (guitar), Brian Baker (bass), Jeff Nelson (drums), as listed by [Dischord](https://next.dischord.com/release/DIS012/first-2-7-s).

The band name, member identities and artwork are real; all availability, practice dates, invitations and rehearsal locations in this fixture are fictional. This is a local review concept, not a claim that Minor Threat uses or endorses the app. No publication or App Store upload performed.

| File | Source and identification | Credit / source license |
| --- | --- | --- |
| group.jpg | [Wikimedia Commons caption](https://commons.wikimedia.org/wiki/File:Minor-threat-malcolm-riviera.jpg) identifies Lyle Preslar, Brian Baker and Ian MacKaye from left to right at the Wilson Center, April 4, 1981. Audience members are excluded from avatar framing. | Malco23, CC BY-SA 3.0; [license](https://creativecommons.org/licenses/by-sa/3.0/). |
| porch.png | [Glen E. Friedman’s gallery description](https://wax-face.com/glenefriedman/minor-threat-poster) identifies the 1983 Dischord House portrait. [Published description](https://thebattleground.eu/2023/10/11/when-the-kids-were-united/) places Jeff in the chair beside the skateboard, to Ian’s right (viewer’s left), and Brian with glasses/light hair on the crate to Ian’s left (viewer’s right). | Glen E. Friedman. Copyrighted gallery photograph; no general reuse license stated. Used here for Keith’s local review concept. |
| logo.png | [Minor Threat logo on Commons](https://commons.wikimedia.org/wiki/File:Minor-Threat-Logo.png). | Commons marks the text logo public domain; trademark rights are separate. |

Original downloaded files are retained without raster modification. SwiftUI uses circular avatar viewports and a fitted logo; viewport coordinates are in `ReviewArtwork.swift`. These views change framing, not source files. The image hashes are recorded in each native capture’s provenance. Artwork is copied into the app bundle only for a Debug Simulator build with `AVAILABILITY_TAB_PREVIEW`; Release excludes it. Load with `--screenshot-band=minor-threat` alongside the existing isolated mock launch.

The September 13 annotation pass replaces the obscured Brian avatar and low-resolution Jeff photo with two caption-identified viewports of `porch.png`. Ian and Lyle retain the existing performance photo; no face-based identity inference is used.

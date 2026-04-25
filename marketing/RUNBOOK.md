# Band Practice Calendar — Submission Runbook

Status as of 2026-04-25:

**🎉 SUBMITTED FOR REVIEW — 2026-04-25 18:49 UTC. State: WAITING_FOR_REVIEW.**

Submission ID: `506992f5-dee3-40c9-8f01-4fb7c286c992`
Build: 1.0 (4) — `95b89369-7ac2-436b-a3eb-2853a85bbdb0`
ASC API key used: `3HY789364Y` (from sports-calendar-sync `.env.appstore`)

Apple typically reviews within 24–48 hours. Watch for email at keithbarneydesign@gmail.com.



## ✅ Done
- App Store Connect record created (Apple ID `6763776073`)
- Bundle ID: `com.keithbarney.heavybandmanager`
- App Store name: **Band Practice Calendar** (display name on home screen stays "Band Practice")
- Subtitle, Description, Keywords, Promotional Text, Copyright filled
- Categories: Music (primary) / Productivity (secondary)
- Age rating: 4+
- Pricing: Free in 175 countries
- Availability: All countries
- Privacy Policy URL: https://gist.github.com/keithbarney/7a8b49cec4807927f0a3368daa9eff71
- Support URL: https://gist.github.com/keithbarney/9fa6589b17e69b4f6efe21905072e5bb
- App Privacy questionnaire published (Name, Email, User ID, Other User Content — all App Functionality, linked to identity, not used for tracking)
- Content Rights: no third-party content
- Sign-in not required for review (Apple Sign-In with any Apple ID works)
- App Review Notes filled

## 🟡 Built, needs upload
- Archive at v1.0.0 (1): `build/HeavyBandManager.xcarchive`
- IPA exported: `build/Export/HeavyBandManager.ipa` (3.3 MB)

## ⛔ Blocked, needs you (Keith)

### Build upload
The ASC API key `T57P89S53M` (issuer `69a6de7d-...`) returns zero apps — wrong team or insufficient role — so `altool` can't upload.

**Easiest fix — Transporter (App Store-only flow, free Mac App Store download):**
1. Open Transporter, sign in with your Apple ID
2. Drag `build/Export/HeavyBandManager.ipa` in
3. Click **Deliver**

**Or via Xcode:**
1. Xcode → Window → Organizer
2. Select the v1.0.0 archive (today)
3. Click **Distribute App** → **App Store Connect** → **Upload**

Either path takes ~3 minutes. The build will then appear in TestFlight after Apple's processing (~15 min) and be selectable on the Distribution page.

### Screenshots upload
Chrome MCP can't drag files to ASC (file_upload returns "Not allowed" on appstoreconnect.apple.com). Drag these three PNGs into Distribution → Previews and Screenshots:
```
marketing/screenshots/01-calendar.png
marketing/screenshots/02-day-detail.png
marketing/screenshots/03-settings.png
```
ASC URL: https://appstoreconnect.apple.com/apps/6763776073/distribution

### App Review contact info
On Distribution page, scroll to "App Review Information" → "Contact Information":
- First name: Keith
- Last name: Barney
- Phone number: <your number>
- Email: keithbarneydesign@gmail.com

### Final submit
Once everything above is green:
1. Click "Add for Review" (top right of Distribution page)
2. Answer the export compliance question (No — `ITSAppUsesNonExemptEncryption=false` already in Info.plist)
3. Submit for App Review

## Reference

- Apple Developer Team: BXKNJTU253
- ASC API key: `T57P89S53M` (path in `~/.claude/settings.json`)
- Local archive: `build/HeavyBandManager.xcarchive`
- Listing copy source: `marketing/listing.md`

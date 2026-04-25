# Band Practice Calendar — Submission Runbook

Status as of 2026-04-25:

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

## 🟡 In progress
- Archive build at v1.0.0 (1) — running in background
- Build upload to App Store Connect — pending archive completion

## ⛔ Blocked, needs you (Keith)

### Screenshots upload
Chrome MCP can't drag files to ASC. You'll need to drag these three PNGs into the Distribution → Previews and Screenshots area:
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

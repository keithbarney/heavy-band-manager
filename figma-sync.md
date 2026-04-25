---
figmaFile: 3AYi6koaVk2OoeoFCW5X5U
figmaFileName: Band Practice
defaultMode: dark
sectionBgVariable: bg/default
stack: swiftui
---

# Figma Sync — Band Practice

## Screen Mapping

| Figma Screen | Node ID | Code File | Notes |
|-------------|---------|-----------|-------|
| LoginView | 26:2 | Views/LoginView.swift | Apple Sign-In |
| OnboardingView - Welcome | 26:3 | Views/OnboardingView.swift | Welcome step (create/join) |
| OnboardingView - Create Band | 26:4 | Views/OnboardingView.swift | Create band form step |
| OnboardingView - Create Band (Name Input) | 133:3360 | Views/OnboardingView.swift | Active keyboard state for band name entry |
| OnboardingView - Create Profile | 104:21237 | Views/OnboardingView.swift | Profile setup step |
| LocationSearchView | 125:2713 | Views/LocationSearchView.swift | Practice location search (MKLocalSearchCompleter) |
| CalendarMonthView | 26:5 | Views/CalendarMonthView.swift | 6-month scrollable grid with overlap dots, band toolbar tap |
| DayDetailSheet | 26:6 | Views/DayDetailSheet.swift | Member availability, overlap windows, schedule |
| BandPickerSheet | 151:3009 | Views/BandPickerSheet.swift | Band list with checkmark, create/join actions |
| BandPickerSheet - Create Band | 153:3009 | Views/BandPickerSheet.swift (CreateBandMiniView) | Quick create band form within picker |
| BandPickerSheet - Join Band | 153:3026 | Views/BandPickerSheet.swift (JoinBandMiniView) | Invite code entry within picker |
| SettingsView | 26:7 | Views/SettingsView.swift | Profile, band, calendar, appearance, delete/leave |
| MemberEditView | 26:8 | Views/SettingsView.swift (MemberEditView) | Profile edit with avatar, name, instrument |
| SettingsView - Delete Band | 153:3040 | Views/SettingsView.swift | confirmationDialog for band deletion (leader only) |
| SettingsView - Leave Band | 153:3050 | Views/SettingsView.swift | confirmationDialog for leaving band (non-leader) |

## Component Mapping

| Figma Component | Node ID | Code File | Notes |
|----------------|---------|-----------|-------|
| .LocationRow | 184:2665 | Views/LocationSearchView.swift (LocationRow) | Reusable list row: pin-container 24x24 + Body title + Subheadline address. Used in LocationSearchView. |
| MemberAvatar | 16:9 | Views/Components/MemberAvatar.swift | Variant set: Size=32, 36, 64 |
| ToastView | 17:12 | Views/Components/ToastView.swift | Variant set: Type=Success, Error, Info |
| DevUserPicker | 18:3 | Views/Components/DevUserPicker.swift | DEBUG-only 2-column user card grid |
| TabBar | 21:17 | Views/BandTabs.swift | Variant set: Active=Calendar, Active=Settings |
| SectionLabel | 22:3 | (inline pattern) | Uppercase section header label |
| InfoRow | 22:13 | (inline pattern) | Variant set: Trailing=Value, Trailing=Chevron |
| ActionCard | 22:15 | Views/OnboardingView.swift | Icon + title + subtitle + chevron card |
| MemberRow | 23:15 | Views/DayDetailSheet.swift | Variant set: Status=Available, Status=Unavailable |
| PracticeCard | 24:14 | Views/DayDetailSheet.swift | Variant set: Role=Leader, Role=Member |
| OverlapWindowCard | 25:17 | Views/DayDetailSheet.swift | Variant set: Role=Leader (w/ Schedule), Role=Member |
| GroupedCard | 25:19 | (inline pattern) | iOS inset grouped card container with dividers |

## Color Variables

Collection: "Semantic Colors" (Dark/Light modes)

| Variable | Dark | Light | Usage |
|----------|------|-------|-------|
| bg/default | #000000 | #FFFFFF | Screen backgrounds |
| bg/secondary | #1C1C1E | #F2F2F7 | Cards, tab bar |
| bg/elevated | #2C2C2E | #FFFFFF | Modals, elevated cards |
| border/default | #38383A | #C6C6C8 | Dividers |
| accent/default | #0A84FF | #007AFF | Interactive elements |
| status/success | #30D158 | #34C759 | Green: practice, available |
| status/warning | #FFD60A | #FFCC00 | Yellow: partial overlap |
| status/danger | #FF453A | #FF3B30 | Red: destructive actions |
| text/primary | #FFFFFF | #000000 | Primary text |
| text/secondary | #EBEBF599 | #3C3C4399 | Secondary text |
| text/tertiary | #EBEBF54D | #3C3C434D | Tertiary text |
| member/* | Fixed | Fixed | 6 member avatar colors |

## Text Styles

iOS type scale mapped to Inter font family (16 styles total).

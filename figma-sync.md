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
| Login | 6:2 | Views/LoginView.swift | Apple Sign-In + dev user picker |
| Onboarding - Welcome | 7:2 | Views/OnboardingView.swift | Welcome step (create/join) |
| Onboarding - Create Band | 8:2 | Views/OnboardingView.swift | Create band form step |
| Calendar - Month View | 10:2 | Views/CalendarMonthView.swift | 6-month scrollable grid with overlap dots |
| Day Detail Sheet | 12:2 | Views/DayDetailSheet.swift | Member availability, overlap windows, schedule |
| Settings | 13:2 | Views/SettingsView.swift | Profile, band, calendar, appearance |

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

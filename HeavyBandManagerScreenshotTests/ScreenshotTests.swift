import XCTest

final class ScreenshotTests: XCTestCase {
    private let app = XCUIApplication()
    private var requestedScreens: Set<String> {
        Set((ProcessInfo.processInfo.environment["SCREENSHOT_SCREENS"] ?? "calendar,day-detail,availability-automatic,availability-manual,settings,band").split(separator: ",").map(String.init))
    }

    private func tapTab(_ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.exists && tab.isHittable { tab.tap(); return }
        let candidates = app.buttons.matching(NSPredicate(format: "label == %@", name)).allElementsBoundByIndex
        guard let button = candidates.first(where: { $0.isHittable }) else {
            XCTFail("Missing native navigation control: \(name)"); return
        }
        button.tap()
    }

    private func expect(_ text: String) {
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), text)
    }

    private func capture(_ screen: String, appearance: String) {
        XCTAssertFalse(app.staticTexts["Mock data"].exists)
        XCTAssertFalse(app.buttons["Review scenario"].exists)
        XCTAssertFalse(app.staticTexts["MOCK-ONLY"].exists)
        // Native actions already wait for app idleness; allow the short sheet/scroll
        // transition to finish. Byte-for-byte PNG polling is unstable around clock updates.
        Thread.sleep(forTimeInterval: 2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "core-\(appearance)-\(screen)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCoreScreens() {
        continueAfterFailure = false
        let minorThreat = ProcessInfo.processInfo.environment["SCREENSHOT_BAND"] == "minor-threat"
        let bandName = minorThreat ? "Minor Threat" : "The Night Shift"
        let memberNames = minorThreat ? ["Ian MacKaye", "Lyle Preslar", "Brian Baker", "Jeff Nelson"] : ["Alex", "Riley", "Sam", "Jamie"]
        if requestedScreens.contains("personal-calendar") {
            XCUIDevice.shared.press(.home)
            let calendar = XCUIApplication(bundleIdentifier: "com.apple.mobilecal")
            calendar.activate()
            let denyLocation = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Don’t Allow"]
            if denyLocation.waitForExistence(timeout: 2) { denyLocation.tap() }
            let bandCalendar = calendar.cells["calendarlist-cell:Default:Band Practice"]
            if !bandCalendar.exists {
                XCTAssertTrue(calendar.buttons["calendars-button"].waitForExistence(timeout: 5))
                calendar.buttons["calendars-button"].tap()
                // Calendar may restore an event popover; the first tap dismisses it.
                if !bandCalendar.waitForExistence(timeout: 1) {
                    calendar.buttons["calendars-button"].tap()
                }
            }
            XCTAssertTrue(bandCalendar.waitForExistence(timeout: 5))
            let calendarIDs = calendar.cells.allElementsBoundByIndex.map(\.identifier).filter { $0.hasPrefix("calendarlist-cell:") }
            for identifier in calendarIDs {
                let cell = calendar.cells[identifier]
                guard cell.exists else { continue }
                if identifier == "calendarlist-cell:Default:Band Practice" {
                    if !cell.isSelected { cell.tap() }
                } else if cell.isSelected { cell.tap() }
            }
            if calendar.buttons["done-button"].exists {
                calendar.buttons["done-button"].tap()
            } else {
                calendar.buttons["calendars-button"].tap()
            }
            let practices = calendar.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "\(bandName) Practice"))
            if !practices.firstMatch.exists && calendar.buttons["listview-button"].exists {
                calendar.buttons["listview-button"].tap()
            }
            XCTAssertTrue(practices.firstMatch.waitForExistence(timeout: 5))
            XCTAssertEqual(practices.count, 3)
            XCTAssertEqual(calendar.staticTexts.matching(identifier: "Studio 4, Riverside Rehearsal Rooms").count, 3)
            if calendar.frame.width > 700 {
                practices.firstMatch.tap()
                calendar.segmentedControls["views-switcher"].buttons["Month"].tap()
                calendar.buttons["today-button"].tap()
                calendar.buttons["listview-button"].tap()
                XCTAssertEqual(practices.count, 3)
            }
            Thread.sleep(forTimeInterval: 2)
            let appearance = ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCES"] ?? "light"
            XCTAssertFalse(appearance.contains(","), "Capture the Calendar demo in one explicitly configured appearance at a time")
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "core-\(appearance)-personal-calendar"; shot.lifetime = .keepAlways; add(shot)
            return
        }
        let appearances = (ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCES"] ?? "light,dark").split(separator: ",").map(String.init)
        let story = ProcessInfo.processInfo.environment["SCREENSHOT_STORY"] == "1"
        for appearance in appearances {
            app.launchArguments = ["--screenshot-mode", "--screenshot-appearance=\(appearance)", "--screenshot-screen=calendar", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            if story { app.launchArguments.append("--screenshot-story") }
            if minorThreat { app.launchArguments.append("--screenshot-band=minor-threat") }
            XCUIDevice.shared.press(.home)
            app.launch()
            // Enter through the Home Screen to clear a previous app's return breadcrumb.
            XCUIDevice.shared.press(.home)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let icons = springboard.icons.matching(identifier: "Band Practice (L)")
            XCTAssertTrue(icons.firstMatch.waitForExistence(timeout: 5))
            // An older review bundle can have the same display name. Verify the
            // exact app bundle is foreground before interacting or capturing.
            for index in (0..<icons.count).reversed() {
                icons.element(boundBy: index).tap()
                if app.wait(for: .runningForeground, timeout: 3) { break }
                XCUIDevice.shared.press(.home)
            }
            XCTAssertEqual(app.state, .runningForeground)
            let target = Calendar.current.date(byAdding: .day, value: 4, to: Date())!
            let key = DateFormatter(); key.locale = Locale(identifier: "en_US_POSIX"); key.dateFormat = "yyyy-MM-dd"
            let day = app.buttons["calendar-day-\(key.string(from: target))"]
            XCTAssertTrue(day.waitForExistence(timeout: 15))
            if requestedScreens.contains("calendar") {
                if story {
                    expect("All members"); expect("3 of 4")
                    for offset in [1, 2, 8, 11, 15, 17] {
                        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                        let cell = app.buttons["calendar-day-\(key.string(from: date))"]
                        let value = cell.value as? String ?? ""
                        XCTAssertTrue(value.contains(offset == 1 ? "Partial availability" : "All members available"))
                        if [8,11,15,17].contains(offset) { XCTAssertTrue(value.contains("Scheduled practice")) }
                    }
                    app.buttons["calendar-view-toggle"].tap()
                    XCTAssertTrue(app.staticTexts.matching(identifier: "\(bandName) Practice").firstMatch.waitForExistence(timeout: 5))
                    XCTAssertEqual(app.staticTexts.matching(identifier: "\(bandName) Practice").count, 4)
                    app.buttons["calendar-view-toggle"].tap()
                    XCTAssertTrue(day.waitForExistence(timeout: 5))
                }
                capture("calendar", appearance: appearance)
            }
            if !requestedScreens.isDisjoint(with: ["day-detail", "confirmation"]) {
                day.tap()
                let heading = DateFormatter(); heading.locale = Locale(identifier: "en_US"); heading.dateFormat = "EEEE, MMMM d"
                expect(heading.string(from: target))
                if !story { expect("Scheduled") }
                expect("7 PM – 9 PM")
                for member in memberNames { expect(member) }
                expect("Best Windows")
                XCTAssertTrue(app.staticTexts["Best Windows"].isHittable)
                if app.frame.width > 700 {
                    // The native iPad sheet initially clips the first time-window row.
                    // A short real scroll keeps the scheduled practice and all members visible.
                    let start = app.staticTexts["Best Windows"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -60)), withVelocity: .slow, thenHoldForDuration: 0.5)
                    for member in memberNames { XCTAssertTrue(app.staticTexts[member].exists) }
                }
                if story {
                    for hours in ["7 PM – 10 PM", "6 PM – 9 PM", "7 PM – 9:30 PM", "6:30 PM – 10 PM"] { expect(hours) }
                    XCTAssertTrue(app.buttons["practice-window-1140-1260"].isHittable)
                }
                if requestedScreens.contains("day-detail") { capture("day-detail", appearance: appearance) }
                if requestedScreens.contains("confirmation") {
                    app.buttons["practice-window-1140-1260"].staticTexts["7 PM – 9 PM"].tap()
                    XCTAssertTrue(app.alerts["Schedule Practice"].waitForExistence(timeout: 5))
                    capture("confirmation", appearance: appearance)
                    app.alerts["Schedule Practice"].buttons["Schedule"].tap()
                    XCTAssertTrue(day.waitForExistence(timeout: 5))
                    day.tap()
                    expect("Scheduled"); expect("7 PM – 9 PM"); expect("Studio 4, Riverside Rehearsal Rooms")
                    let options = app.buttons["Practice options"]
                    XCTAssertTrue(options.waitForExistence(timeout: 5))
                    options.tap()
                    XCTAssertTrue(app.buttons["Remove"].waitForExistence(timeout: 5))
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.1)).tap()
                }
                app.buttons["Done"].tap()
                XCTAssertTrue(day.waitForExistence(timeout: 5))
            }
            if !requestedScreens.isDisjoint(with: ["availability-automatic", "availability-manual"]) {
                tapTab("Availability")
                if requestedScreens.contains("availability-automatic") {
                    app.buttons["Automatic"].tap()
                    expect("Availability from your calendar")
                    expect("Practice hours")
                    capture("availability-automatic", appearance: appearance)
                }
                if requestedScreens.contains("availability-manual") {
                    app.buttons["Manual"].tap()
                    expect("Share the same hours each week.")
                    XCTAssertTrue(app.buttons["Mon"].exists)
                    capture("availability-manual", appearance: appearance)
                }
            }
            if requestedScreens.contains("settings") {
                tapTab("Settings"); expect("Practices on my calendar"); expect("Practice calendar"); expect("Band Practice")
                capture("settings", appearance: appearance)
            }
            if requestedScreens.contains("band") {
                tapTab("Band"); expect(bandName); expect(minorThreat ? "THREAT" : "NIGHT24")
                for member in memberNames { expect(member) }
                if minorThreat {
                    for member in memberNames { XCTAssertTrue(app.images["member-photo-\(member)"].exists, "Missing photo: \(member)") }
                    XCTAssertTrue(app.images["band-logo-photo"].exists)
                }
                capture("band", appearance: appearance)
            }
            app.terminate()
        }
    }
}

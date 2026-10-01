import XCTest

/// Functional review uses isolated mock services; no production calendar/backend writes.
final class PracticeFeatureTests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.keithbarney.heavybandmanager.local")

    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--widget-review", "--screenshot-screen=band"]
        if name.contains("testLocationSaveCancelAndPracticeOverride") {
            // This test needs future practices even when a saved mock run is weeks old.
            app.launchArguments.append("--reset-widget-review")
        }
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if name.contains("testWidgetBandConfiguration"), home.staticTexts["Upcoming Practices"].exists,
           home.buttons["Band"].exists { return }
        app.launch()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertPracticeDay(offset: Int) {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
        XCTAssertTrue(app.navigationBars[formatter.string(from: day)].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.buttons["Practice options"].exists)
    }

    func testLocationSaveCancelAndPracticeOverride() {
        let editDefault = app.buttons["edit-default-practice-location"]
        XCTAssertTrue(editDefault.waitForExistence(timeout: 10), app.debugDescription)
        editDefault.tap()
        XCTAssertTrue(app.buttons["Clear location"].waitForExistence(timeout: 5))
        if app.buttons["Clear location"].exists { app.buttons["Clear location"].tap() }
        let field = app.descendants(matching: .any).matching(identifier: "practice-location-input").firstMatch
        field.tap()
        field.typeText("Review default studio")
        app.buttons["save-practice-location"].tap()
        XCTAssertTrue(editDefault.waitForExistence(timeout: 5))
        XCTAssertTrue(editDefault.label.contains("Review default studio"))
        capture("location-default-saved")
        editDefault.tap()
        if app.buttons["Clear location"].exists { app.buttons["Clear location"].tap() }
        app.buttons["Cancel"].tap()
        XCTAssertTrue(editDefault.waitForExistence(timeout: 5))
        XCTAssertTrue(editDefault.label.contains("Review default studio"))

        app.buttons["Calendar"].firstMatch.tap()
        let upcoming = app.buttons["Show upcoming practices"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 5), app.debugDescription)
        upcoming.tap()
        let practice = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "The Night Shift Practice")).firstMatch
        XCTAssertTrue(practice.waitForExistence(timeout: 5))
        practice.tap()
        XCTAssertTrue(app.buttons["Practice options"].waitForExistence(timeout: 5))
        app.buttons["Practice options"].tap()
        app.buttons["Edit Location"].tap()
        if app.buttons["Clear location"].exists { app.buttons["Clear location"].tap() }
        field.tap()
        field.typeText("Review one-off studio")
        app.buttons["save-practice-location"].tap()
        XCTAssertTrue(app.staticTexts["Review one-off studio"].waitForExistence(timeout: 5))
        capture("location-practice-saved")
        app.buttons["Practice options"].tap()
        app.buttons["Edit Location"].tap()
        if app.buttons["Clear location"].exists { app.buttons["Clear location"].tap() }
        app.buttons["save-practice-location"].tap()
        XCTAssertTrue(app.buttons["Practice options"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Review one-off studio"].exists)
        capture("location-practice-cleared")
    }

    func testSmallWidgetLink() {
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let widgets = home.icons.matching(NSPredicate(format: "label == %@ AND value == %@", "Band Practice (L)", "Widget"))
        let small = widgets.allElementsBoundByIndex.first { $0.buttons.count == 0 }
        XCTAssertNotNil(small, home.debugDescription)
        capture("widget-small-home")
        small?.tap()
        assertPracticeDay(offset: 1)
        capture("widget-small-link")
        XCUIDevice.shared.press(.home)
    }

    /// Gallery addition avoids inconsistent Simulator resize-menu automation.
    private func addWidget(galleryPage: Int, expectedRows: Int, header: String? = nil) -> XCUIElement {
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).press(forDuration: 1.5)
        if !home.buttons["Edit"].waitForExistence(timeout: 3), home.buttons["Edit Home Screen"].exists {
            home.buttons["Edit Home Screen"].tap()
        }
        XCTAssertTrue(home.buttons["Edit"].waitForExistence(timeout: 5), home.debugDescription)
        home.buttons["Edit"].tap()
        let add = home.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Add Widget")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let search = home.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("Band Practice")
        let result = home.cells["Band Practice (L)"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10), home.debugDescription)
        result.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        let preview = home.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Upcoming Practices")).firstMatch
        for _ in 0..<galleryPage { preview.swipeLeft() }
        let size = galleryPage == 0 ? "Small" : (galleryPage == 1 ? "Medium" : "Large")
        XCTAssertTrue(home.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND value CONTAINS %@", "Upcoming Practices", size)).firstMatch.waitForExistence(timeout: 5))
        add.tap()
        if home.buttons["Done"].waitForExistence(timeout: 5) { home.buttons["Done"].tap() }
        let widgets = home.icons.matching(NSPredicate(format: "label == %@ AND value == %@", "Band Practice (L)", "Widget"))
        let loaded = NSPredicate { _, _ in
            widgets.allElementsBoundByIndex.contains { $0.buttons.count == expectedRows && (header == nil || $0.staticTexts[header!].exists) }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: loaded, object: nil)], timeout: 20), .completed, home.debugDescription)
        return widgets.allElementsBoundByIndex.first { $0.buttons.count == expectedRows && (header == nil || $0.staticTexts[header!].exists) } ?? widgets.firstMatch
    }

    func testAllBandsSmallWidget() {
        let widget = addWidget(galleryPage: 0, expectedRows: 0, header: "Next · All bands")
        XCTAssertTrue(widget.staticTexts["The Night Shift"].exists)
        capture("all-bands-small-widget")
        widget.tap()
        assertPracticeDay(offset: 1)
        XCUIDevice.shared.press(.home)
    }

    func testAllBandsScheduleFromApp() {
        app.buttons["Calendar"].firstMatch.tap()
        app.buttons["Show upcoming practices"].tap()
        app.buttons["show-all-band-practices"].tap()
        XCTAssertTrue(app.navigationBars["All Band Practices"].waitForExistence(timeout: 5))
        app.swipeUp()
        let second = app.buttons["all-bands-practice-30000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        second.tap()
        assertPracticeDay(offset: 2)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["All Band Practices"].waitForExistence(timeout: 5))
    }

    /// Run with the Simulator's accessibility text size enabled.
    func testAllBandsAccessibleWidgets() {
        XCUIDevice.shared.press(.home)
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let widgets = home.icons.matching(NSPredicate(format: "label == %@ AND value == %@", "Band Practice (L)", "Widget"))
        func largeWidget() -> XCUIElement? {
            widgets.allElementsBoundByIndex.first { $0.buttons.count == 3 && $0.buttons["View all 2 bands"].exists }
        }
        XCUIDevice.shared.press(.home)
        for _ in 0..<5 {
            if largeWidget() != nil { break }
            home.swipeLeft()
        }
        capture("all-bands-accessible-home-search")
        XCTAssertNotNil(largeWidget(), home.debugDescription)
        let large = largeWidget()!
        XCTAssertTrue(large.staticTexts["Sunday Static"].exists)
        XCTAssertTrue(widgets.allElementsBoundByIndex.contains { $0.buttons.count == 2 && $0.buttons["View all 2 bands"].exists })
        capture("all-bands-accessible-widgets")
        large.buttons["View all 2 bands"].tap()
        XCTAssertTrue(app.navigationBars["All Band Practices"].waitForExistence(timeout: 10))
        capture("all-bands-accessible-schedule")
    }

    func testAllBandsWidgetsAndFullSchedule() {
        for (page, rows, name) in [(1, 5, "medium"), (2, 7, "large")] {
            let widget = addWidget(galleryPage: page, expectedRows: rows)
            XCTAssertTrue(widget.staticTexts["The Night Shift"].exists)
            XCTAssertTrue(widget.staticTexts["Sunday Static"].exists)
            capture("all-bands-\(name)-widget")
            if page == 1 {
                widget.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eastside Studio")).firstMatch.tap()
                assertPracticeDay(offset: 2)
                XCTAssertTrue(app.staticTexts["Eastside Studio"].exists)
            } else {
                app.terminate()
                widget.buttons["View all 2 bands"].tap()
                XCTAssertTrue(app.navigationBars["All Band Practices"].waitForExistence(timeout: 10), app.debugDescription)
                capture("all-bands-schedule-top")
                let practice = app.buttons["all-bands-practice-30000000-0000-0000-0000-000000000001"]
                for _ in 0..<5 {
                    if practice.isHittable { break }
                    app.swipeUp()
                }
                XCTAssertTrue(practice.isHittable, app.debugDescription)
                capture("all-bands-schedule-second-band")
                practice.tap()
                assertPracticeDay(offset: 2)
                XCTAssertTrue(app.staticTexts["Eastside Studio"].exists)
            }
        }
    }

    func testWidgetBandConfiguration() {
        let home = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let widget = home.icons.matching(NSPredicate(format: "label == %@ AND value == %@", "Band Practice (L)", "Widget")).firstMatch
        let bandField = home.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Band")).firstMatch
        if !home.staticTexts["Upcoming Practices"].exists || !bandField.exists {
            XCUIDevice.shared.press(.home)
            XCTAssertTrue(widget.waitForExistence(timeout: 10))
            widget.press(forDuration: 1.5)
            XCTAssertTrue(home.buttons["Edit Widget"].waitForExistence(timeout: 5))
            home.buttons["Edit Widget"].tap()
        }
        XCTAssertTrue(bandField.waitForExistence(timeout: 30), home.debugDescription)
        capture("widget-band-configuration")
        // Start from either persisted selection and exercise an actual change.
        for bandName in ["The Night Shift", "Sunday Static"] {
            let selectedBands = home.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["The Night Shift", "Sunday Static"]))
            if selectedBands.count > 0 {
                selectedBands.element(boundBy: selectedBands.count - 1).tap()
            } else {
                XCTAssertTrue(home.buttons["Band"].exists, home.debugDescription)
                home.buttons["Band"].tap()
            }
            let choices = home.descendants(matching: .any).matching(NSPredicate(format: "label == %@", bandName))
            XCTAssertTrue(choices.firstMatch.waitForExistence(timeout: 15), home.debugDescription)
            choices.element(boundBy: choices.count - 1).tap()
            XCTAssertTrue(bandField.waitForExistence(timeout: 10))
        }
        home.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        XCTAssertTrue(widget.staticTexts["Sunday Static"].waitForExistence(timeout: 30), home.debugDescription)
        capture("widget-selected-band")
        // The app opens its usual band and publishes that preference again.
        app.launch()
        XCTAssertTrue(app.buttons["edit-default-practice-location"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(widget.staticTexts["Sunday Static"].waitForExistence(timeout: 15))
        let practice = widget.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Eastside Studio")).firstMatch
        if widget.buttons.count == 0 { widget.tap() } else {
            XCTAssertTrue(practice.waitForExistence(timeout: 10))
            practice.tap()
        }
        assertPracticeDay(offset: 2)
        XCTAssertTrue(app.staticTexts["Eastside Studio"].exists)
        capture("widget-configured-band-link")
    }

}

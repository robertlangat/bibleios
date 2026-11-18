import XCTest

final class BibleDailyUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        // Ads off in UI tests so interstitials can't cover the screen.
        app.launchArguments = ["-disableAds"] + (reset ? ["-resetData"] : [])
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    private func screenshot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func waitForTitle(_ app: XCUIApplication, _ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "label == %@", title)
        let exp = expectation(for: predicate, evaluatedWith: app.buttons["reader_title"])
        if XCTWaiter.wait(for: [exp], timeout: 10) != .completed {
            XCTFail("Reader title was \"\(app.buttons["reader_title"].label)\", expected \"\(title)\"", file: file, line: line)
        }
    }

    private func openReference(_ app: XCUIApplication, _ query: String, title: String) {
        app.tabBars.buttons["Search"].tap()
        let field = element(app, "search_field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText(query)
        let result = element(app, "ref_result")
        XCTAssertTrue(result.waitForExistence(timeout: 10), "No reference result for \(query)")
        result.tap()
        waitForTitle(app, title)
    }

    /// Lists and grids are lazy, so scroll until the element exists and can be tapped.
    private func tapUntilHittable(_ app: XCUIApplication, _ id: String) {
        let e = element(app, id)
        _ = e.waitForExistence(timeout: 3)
        var tries = 0
        while !(e.exists && e.isHittable) && tries < 15 {
            app.swipeUp(velocity: .slow)
            tries += 1
        }
        XCTAssertTrue(e.exists, "\(id) missing")
        e.tap()
    }

    func test1_FirstLaunchShowsVerseOfDay() {
        let app = launch(reset: true)
        let votd = element(app, "votd_text")
        XCTAssertTrue(votd.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(votd.label.count, 10)
        XCTAssertTrue(element(app, "votd_ref").exists)
        screenshot(app, "01_home")
    }

    func test2_ChapterNavigation() {
        let app = launch(reset: true)
        app.tabBars.buttons["Read"].tap()
        waitForTitle(app, "Genesis 1")
        XCTAssertTrue(element(app, "verse_1").label.contains("In the beginning, God created"))
        screenshot(app, "02_reader_genesis_1")

        app.buttons["next_chapter"].tap()
        waitForTitle(app, "Genesis 2")
        app.buttons["prev_chapter"].tap()
        waitForTitle(app, "Genesis 1")

        // Book picker → Genesis 50, then across the book boundary.
        app.buttons["reader_title"].tap()
        tapUntilHittable(app, "book_1")
        tapUntilHittable(app, "chapter_50")
        waitForTitle(app, "Genesis 50")
        app.buttons["next_chapter"].tap()
        waitForTitle(app, "Exodus 1")

        app.buttons["reader_title"].tap()
        XCTAssertTrue(app.buttons["New Testament"].waitForExistence(timeout: 5))
        app.buttons["New Testament"].tap()
        tapUntilHittable(app, "book_66")
        tapUntilHittable(app, "chapter_22")
        waitForTitle(app, "Revelation 22")
    }

    func test3_SearchReferences() {
        let app = launch(reset: true)
        openReference(app, "John 3:16", title: "John 3")
        let v16 = element(app, "verse_16")
        XCTAssertTrue(v16.waitForExistence(timeout: 5))
        XCTAssertTrue(v16.isHittable, "John 3:16 should be scrolled into view")
        XCTAssertTrue(v16.label.contains("For God so loved the world"))
        screenshot(app, "03_john_3_16")

        openReference(app, "Jn 3:16", title: "John 3")
        openReference(app, "Psalm 23", title: "Psalms 23")
        XCTAssertTrue(element(app, "verse_1").label.contains("Yahweh is my shepherd"))

        app.tabBars.buttons["Search"].tap()
        let field = element(app, "search_field")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) + "born anew")
        XCTAssertTrue(element(app, "result_43_3_3").waitForExistence(timeout: 10))
        screenshot(app, "04_search_phrase")
    }

    func test4_ShareVerse() {
        let app = launch(reset: true)
        openReference(app, "John 3:16", title: "John 3")
        element(app, "verse_16").tap()
        let share = element(app, "action_share")
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        screenshot(app, "05_verse_actions")
        share.tap()
        // The system share sheet opens with the verse text.
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10), "Share sheet did not open")
        screenshot(app, "06_share_sheet")
    }

    func test5_NotesAndPositionSurviveRestart() {
        var app = launch(reset: true)
        openReference(app, "Romans 8:28", title: "Romans 8")
        let verse = element(app, "verse_28")
        XCTAssertTrue(verse.waitForExistence(timeout: 5))
        verse.tap()

        XCTAssertTrue(element(app, "action_bookmark").waitForExistence(timeout: 5))
        element(app, "action_bookmark").tap()
        element(app, "highlight_1").tap()
        element(app, "action_note").tap()
        let note = element(app, "note_field")
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.typeText("Persistence test note")
        element(app, "note_save").tap()

        let marked = NSPredicate(format: "label CONTAINS 'Bookmarked' AND label CONTAINS 'Highlighted' AND label CONTAINS 'Has note'")
        wait(for: [expectation(for: marked, evaluatedWith: element(app, "verse_28"))], timeout: 10)
        screenshot(app, "07_marked_verse")

        // Quit the app completely and start it again.
        app.terminate()
        app = launch(reset: false)
        XCTAssertTrue(element(app, "votd_text").waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "continue_reading").label.contains("Romans 8"))

        app.tabBars.buttons["Saved"].tap()
        app.buttons["Notes"].tap()
        XCTAssertTrue(app.staticTexts["Persistence test note"].waitForExistence(timeout: 5))
        screenshot(app, "08_saved_notes_after_restart")

        app.tabBars.buttons["Read"].tap()
        waitForTitle(app, "Romans 8")
        let v28 = element(app, "verse_28")
        XCTAssertTrue(v28.waitForExistence(timeout: 5))
        XCTAssertTrue(v28.label.contains("Has note"))
        screenshot(app, "09_reader_after_restart")
    }

    func test6_DarkModeAndSettings() {
        let app = launch(reset: true)
        element(app, "open_settings").tap()
        XCTAssertTrue(app.buttons["Dark"].waitForExistence(timeout: 5))
        app.buttons["Dark"].tap()
        screenshot(app, "10_settings_dark")
        app.buttons["Light"].tap()
        XCTAssertTrue(app.switches["reminder_switch"].exists || element(app, "reminder_switch").exists)
    }
}

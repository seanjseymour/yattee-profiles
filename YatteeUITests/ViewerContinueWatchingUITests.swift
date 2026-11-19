//
//  ViewerContinueWatchingUITests.swift
//  YatteeUITests
//
//  Viewer switching and Continue Watching, driven with Siri Remote presses in
//  the Debug-only `-YatteeUITestMode` (two viewers, A has seeded history).
//

import XCTest

final class ViewerContinueWatchingUITests: XCTestCase {
    // Must match `UITestMode` in the app.
    private let viewerA = "0000000A-0000-4000-8000-000000000000"
    private let viewerB = "0000000B-0000-4000-8000-000000000000"
    private let seededTitle = "UITest A Seeded Video"
    private let clipTitle = "UITest Local Clip"

    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-YatteeUITestMode"]
    }

    // MARK: - Tests

    /// 1a on Home: after A → B in the picker, A's item must leave the shelf.
    func testSwitchViewerUpdatesHomeShelf() {
        launch()
        XCTAssertTrue(waitUntil(15) { self.contains(self.shelf, self.seededTitle) },
                      "Setup: A's seeded item is not on A's Home shelf")
        checkpoint("home-A-before-switch")

        switchViewer(to: viewerB, name: "B")
        let cleared = waitUntil(8) { !self.contains(self.app, self.seededTitle) }
        checkpoint("home-B-after-switch")
        record("home: after switch to B, A's item \(cleared ? "is gone" : "is STILL shown")")
        XCTAssertTrue(cleared, "Home still shows A's item after switching to B (hypothesis 1a)")
    }

    /// 1a on the Continue Watching screen (opened as the startup tab).
    func testSwitchViewerUpdatesContinueWatchingScreen() {
        launch(startTab: "continueWatching")
        XCTAssertTrue(waitUntil(15) { self.contains(self.app, self.seededTitle) },
                      "Setup: A's seeded item is not on the Continue Watching screen")
        checkpoint("continueWatching-A-before-switch")

        switchViewer(to: viewerB, name: "B")
        let cleared = waitUntil(8) { !self.contains(self.app, self.seededTitle) }
        checkpoint("continueWatching-B-after-switch")
        record("continueWatching: after switch to B, A's item \(cleared ? "is gone" : "is STILL shown")")
        XCTAssertTrue(cleared, "Continue Watching still shows A's item after switching to B (hypothesis 1a)")
    }

    /// Symptom 2 on the plain path: B plays the local clip, returns, B's shelf shows it.
    func testPlayAndReturnShowsProgressForCurrentViewer() {
        launch()
        switchViewer(to: viewerB, name: "B")
        XCTAssertFalse(contains(shelf, clipTitle), "Setup: B's shelf already shows the clip")

        playClipFromBookmarks(seconds: 15, label: "B")
        backOutOfPlayer()
        let shown = waitUntil(10) { self.contains(self.shelf, self.clipTitle) }
        checkpoint("home-B-after-playback")
        record("plain path: B's shelf \(shown ? "shows" : "does NOT show") the clip B played; shelf texts: \(shelfTexts())")
        XCTAssertTrue(shown, "B's shelf does not show the clip B just played (symptom 2)")
    }

    /// 2b: play as A, Menu out, switch to B, resume via Now Playing, Menu out.
    /// Documents where the progress lands; correctness is Sean's decision.
    func testNowPlayingAfterSwitchSavesToNewViewer() {
        launch()
        playClipFromBookmarks(seconds: 15, label: "A")
        backOutOfPlayer()
        let aAfterPlay = waitUntil(10) { self.contains(self.shelf, self.clipTitle) }
        checkpoint("home-A-after-playback")
        record("step 1: A's shelf \(aAfterPlay ? "shows" : "does NOT show") the clip; shelf texts: \(shelfTexts())")

        switchViewer(to: viewerB, name: "B")
        let bBeforeResume = contains(shelf, clipTitle)
        checkpoint("home-B-before-resume")
        record("step 2: after switch, B's shelf \(bBeforeResume ? "shows" : "does not show") the clip")

        XCTAssertTrue(openNowPlayingFromSidebar(), "Could not reach Now Playing in the sidebar; focus: \(focusedDescription())")
        sleep(15)
        checkpoint("player-B-resumed")
        backOutOfPlayer()
        let bAfterResume = waitUntil(10) { self.contains(self.shelf, self.clipTitle) }
        checkpoint("home-B-after-resume")
        record("step 3: after resume as B, B's shelf \(bAfterResume ? "shows" : "does NOT show") the clip; shelf texts: \(shelfTexts())")

        switchViewer(to: viewerA, name: "A")
        let aAtEnd = waitUntil(8) { self.contains(self.shelf, self.clipTitle) }
        checkpoint("home-A-at-end")
        record("step 4: A's shelf \(aAtEnd ? "shows" : "does not show") the clip; shelf texts: \(shelfTexts())")

        let landed: String
        switch (bAfterResume, aAtEnd) {
        case (true, true): landed = "both A and B"
        case (true, false): landed = "B only"
        case (false, true): landed = "A only (2b)"
        case (false, false): landed = "neither"
        }
        record("RESULT nowPlaying: progress after the switch is visible for \(landed)")
    }

    // MARK: - Steps

    private func launch(startTab: String? = nil) {
        if let startTab {
            app.launchArguments += ["-YatteeUITestStartTab", startTab]
        }
        app.launch()
        dismissSystemAlertIfPresent()
        XCTAssertTrue(app.buttons["viewerPicker.open"].waitForExistence(timeout: 45),
                      "App did not reach a tab root with the viewer launcher")
        sleep(3)  // let the first focus land
        checkpoint("launched")
    }

    private func switchViewer(to id: String, name: String) {
        let launcher = app.buttons["viewerPicker.open"]
        XCTAssertTrue(moveFocus(to: launcher, trying: [.right, .up]),
                      "Could not focus the viewer launcher; focus: \(focusedDescription())")
        remote.press(.select)
        let row = app.buttons["viewerPicker.select.\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Viewer picker did not open")
        sleep(1)
        XCTAssertTrue(moveFocus(to: row, trying: [.down, .up]),
                      "Could not focus viewer \(name) in the picker; focus: \(focusedDescription())")
        checkpoint("picker-\(name)-focused")
        remote.press(.select)
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "Viewer picker did not close")
        sleep(2)
    }

    private func playClipFromBookmarks(seconds: UInt32, label: String) {
        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", clipTitle)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 15), "The bookmarked clip is not on Home")
        XCTAssertTrue(moveFocus(to: card, trying: [.left, .down, .up]),
                      "Could not focus the bookmarked clip; focus: \(focusedDescription())")
        checkpoint("home-\(label)-clip-focused")
        remote.press(.select)
        sleep(seconds)
        checkpoint("player-\(label)-after-\(seconds)s")
        record("player \(label): launcher visible during playback = \(app.buttons["viewerPicker.open"].exists); texts: \(visibleTexts())")
    }

    /// Menu hides the controls first, then collapses the player.
    private func backOutOfPlayer() {
        let launcher = app.buttons["viewerPicker.open"]
        for _ in 0..<3 {
            remote.press(.menu)
            if launcher.waitForExistence(timeout: 3) {
                sleep(2)
                return
            }
        }
        XCTFail("Could not leave the player with Menu; focus: \(focusedDescription())")
    }

    /// Left into the sidebar, then up to the Now Playing item at its top.
    private func openNowPlayingFromSidebar() -> Bool {
        for _ in 0..<8 {
            remote.press(.left)
            usleep(700_000)
            let focus = focused
            if focus.exists, focus.frame.minX < 500 { break }
        }
        checkpoint("sidebar-open")
        for _ in 0..<12 {
            let focus = focused
            if focus.exists, focus.label.contains(clipTitle), focus.frame.minX < 500 {
                remote.press(.select)
                return true
            }
            remote.press(.up)
            usleep(600_000)
        }
        return false
    }

    // MARK: - Helpers

    private var shelf: XCUIElement { app.otherElements["home.continueWatchingShelf"] }

    private var focused: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).firstMatch
    }

    private func contains(_ root: XCUIElement, _ title: String) -> Bool {
        guard root.exists else { return false }
        return root.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", title)).count > 0
    }

    private func focusedDescription() -> String {
        let focus = focused
        guard focus.exists else { return "none" }
        return "type=\(focus.elementType.rawValue) id='\(focus.identifier)' label='\(focus.label)' x=\(Int(focus.frame.minX))"
    }

    private func shelfTexts() -> [String] {
        guard shelf.exists else { return ["<no shelf>"] }
        return shelf.staticTexts.allElementsBoundByIndex.map(\.label)
    }

    private func visibleTexts() -> [String] {
        Array(app.staticTexts.allElementsBoundByIndex.prefix(15).map(\.label))
    }

    /// Presses each direction until the element has focus or focus stops moving.
    private func moveFocus(to element: XCUIElement, trying directions: [XCUIRemote.Button], rounds: Int = 3) -> Bool {
        if element.hasFocus { return true }
        for _ in 0..<rounds {
            for direction in directions {
                for _ in 0..<12 {
                    let before = focusedDescription()
                    remote.press(direction)
                    usleep(500_000)
                    if element.hasFocus { return true }
                    if focusedDescription() == before { break }
                }
            }
        }
        return element.hasFocus
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            usleep(500_000)
        } while Date() < deadline
        return condition()
    }

    private func dismissSystemAlertIfPresent() {
        let system = XCUIApplication(bundleIdentifier: "com.apple.PineBoard")
        if system.alerts.firstMatch.waitForExistence(timeout: 3) {
            checkpoint("system-alert")
            record("system alert at launch: \(system.alerts.firstMatch.label)")
            remote.press(.select)
            sleep(1)
        }
    }

    private func checkpoint(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func record(_ text: String) {
        print("UITEST-RESULT [\(name)]: \(text)")
        let attachment = XCTAttachment(string: text)
        attachment.name = "result"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

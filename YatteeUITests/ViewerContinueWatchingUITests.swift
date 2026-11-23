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

    /// 2b fix (Sean, 2026-11-20): a viewer switch stops the player. A plays,
    /// Menu out (playback continues in the background), switch to B. B gets no
    /// Now Playing item and an empty shelf; A's progress stops where the switch
    /// saved it.
    func testViewerSwitchStopsPlayer() {
        launch()
        playClipFromBookmarks(seconds: 15, label: "A")
        backOutOfPlayer()
        XCTAssertTrue(waitUntil(10) { self.contains(self.shelf, self.clipTitle) },
                      "Setup: A's shelf does not show the clip A played; shelf texts: \(shelfTexts())")
        record("symbol buttons before switch: \(playCircleButtons())")
        // Positive control for the sidebar check used after the switch.
        XCTAssertTrue(nowPlayingReachableInSidebar(),
                      "Setup: focus cannot reach Now Playing while A's player is collapsed; \(playCircleButtons())")
        XCTAssertTrue(waitUntil(10) { self.contains(self.shelf, self.clipTitle) }, "Setup: shelf not visible after the sidebar check")
        let beforeSwitch = clipRemainingSeconds()
        checkpoint("home-A-before-switch")
        record("step 1: A before switch: clip remaining=\(beforeSwitch.map(String.init) ?? "nil")s; shelf texts: \(shelfTexts())")
        XCTAssertNotNil(beforeSwitch, "Setup: could not read A's remaining time for the clip")

        switchViewer(to: viewerB, name: "B")
        // The collapsed sidebar can keep a zero-size cell for a removed tab in
        // the accessibility tree, so judge by what focus can reach: open the
        // sidebar and climb it to the top.
        sleep(2)
        let nowPlayingGone = !nowPlayingReachableInSidebar()
        record("symbol buttons after switch: \(playCircleButtons())")
        let bShelfEmpty = !contains(shelf, clipTitle)
        checkpoint("home-B-after-switch")
        record("step 2: after switch to B: Now Playing \(nowPlayingGone ? "gone" : "STILL shown"), B's shelf \(bShelfEmpty ? "has no clip" : "SHOWS the clip"); shelf texts: \(shelfTexts())")
        XCTAssertTrue(nowPlayingGone, "Now Playing still offers A's video to B after the switch")
        XCTAssertTrue(bShelfEmpty, "B's shelf shows the clip only A played")

        // With the old behaviour A's player kept saving in the background here.
        sleep(30)
        let stillGone = !nowPlayingReachableInSidebar() && !contains(shelf, clipTitle)
        checkpoint("home-B-after-30s")
        record("step 3: B after 30 s: Now Playing absent and B's shelf empty = \(stillGone)")
        XCTAssertTrue(stillGone, "Now Playing or the clip came back on B's Home")

        switchViewer(to: viewerA, name: "A")
        XCTAssertTrue(waitUntil(8) { self.contains(self.shelf, self.clipTitle) },
                      "A's shelf lost the clip; shelf texts: \(shelfTexts())")
        let afterSwitch = clipRemainingSeconds()
        checkpoint("home-A-after-switch-back")
        sleep(10)
        let settled = clipRemainingSeconds()
        checkpoint("home-A-10s-later")
        record("step 4: A remaining: before switch=\(beforeSwitch.map(String.init) ?? "nil")s, back on A=\(afterSwitch.map(String.init) ?? "nil")s, 10 s later=\(settled.map(String.init) ?? "nil")s")

        guard let beforeSwitch, let afterSwitch else {
            return XCTFail("Could not read A's remaining time; shelf texts: \(shelfTexts())")
        }
        // Between reading the shelf and the switch, A's collapsed player still
        // plays, and the switch saves that last position (the periodic save
        // runs every 5 s, the picker takes a few seconds). 15 s covers that;
        // a player that survived the switch adds 30+ s on B's Home.
        let drift = beforeSwitch - afterSwitch
        record("RESULT stopOnSwitch: A's remaining time moved \(drift) s across the switch")
        XCTAssertTrue((0...15).contains(drift),
                      "A's remaining time moved \(drift) s across the switch (expected 0–15 s, the switch's final save)")
        XCTAssertEqual(settled, afterSwitch, "A's progress still advances after the switch: the player was not stopped")
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

    /// Menu hides the controls first, then collapses the player. The views
    /// under the player stay in the accessibility tree, so "back on Home" is
    /// judged by where focus is, not by whether Home elements exist.
    private func backOutOfPlayer() {
        for press in 1...3 {
            remote.press(.menu)
            sleep(3)
            if homeHasFocus() {
                record("left the player after \(press) Menu press(es); focus: \(focusedDescription())")
                return
            }
        }
        XCTFail("Could not leave the player with Menu; focus: \(focusedDescription())")
    }

    /// Opens the sidebar (Left from content; Up when Left does not reach it),
    /// climbs it with Up and reports whether focus landed on Now Playing.
    /// Leaves with Right, never Menu (Menu at the Home root leaves the app).
    private func nowPlayingReachableInSidebar() -> Bool {
        for _ in 0..<6 where !sidebarHasFocus() {
            remote.press(.left)
            sleep(1)
            if !sidebarHasFocus() {
                remote.press(.up)
                sleep(1)
            }
        }
        guard sidebarHasFocus() else {
            XCTFail("Left did not open the sidebar; focus: \(focusedDescription())")
            return false
        }
        var trail: [String] = [focusedSidebarSymbol() ?? "?"]
        var reached = focusedSidebarSymbol() == "play.circle.fill"
        for _ in 0..<8 where !reached {
            let before = focusedDescription()
            remote.press(.up)
            sleep(1)
            trail.append(focusedSidebarSymbol() ?? "?")
            reached = focusedSidebarSymbol() == "play.circle.fill"
            if focusedDescription() == before { break }
        }
        checkpoint("sidebar-top")
        record("sidebar Up trail: \(trail); Now Playing reached = \(reached); visible item frame=\(nowPlayingItem.exists ? "\(nowPlayingItem.frame)" : "none")")
        remote.press(.right)
        sleep(2)
        return reached
    }

    // MARK: - Helpers

    private var shelf: XCUIElement { app.otherElements["home.continueWatchingShelf"] }

    /// The sidebar's Now Playing tab: symbol `play.circle.fill` and the playing
    /// video's title. Home's Continue Watching shortcut uses the same symbol.
    private var nowPlayingItem: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND label CONTAINS %@",
                                         "play.circle.fill", clipTitle)).firstMatch
    }

    private func playCircleButtons() -> [String] {
        app.buttons.matching(identifier: "play.circle.fill").allElementsBoundByIndex
            .map { "'\($0.label)' x=\(Int($0.frame.minX)) y=\(Int($0.frame.minY))" }
    }

    private let sidebarSymbols: Set<String> = ["play.circle.fill", "magnifyingglass", "house.fill",
                                               "arrow.down.circle", "server.rack", "gear",
                                               "antenna.radiowaves.left.and.right", "play.circle"]

    /// The sidebar symbol of the focused row. Focus lands on the row's cell;
    /// the symbol-named button (the tab) is inside it.
    private func focusedSidebarSymbol() -> String? {
        let focus = focused
        guard focus.exists else { return nil }
        if sidebarSymbols.contains(focus.identifier) { return focus.identifier }
        for query in [focus.buttons, focus.images] {
            let match = query.matching(NSPredicate(format: "identifier IN %@", Array(sidebarSymbols))).firstMatch
            if match.exists { return match.identifier }
        }
        return nil
    }

    private func sidebarHasFocus() -> Bool { focusedSidebarSymbol() != nil }

    /// Focus is on Home or a tab root, not inside the player.
    private func homeHasFocus() -> Bool {
        let focus = focused
        guard focus.exists else { return false }
        if focus.identifier == "viewerPicker.open" || sidebarHasFocus() { return true }
        return [clipTitle, seededTitle, "Resume", "Browse sources"].contains { focus.label.contains($0) }
    }

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
        let symbol = focusedSidebarSymbol().map { " sidebar=\($0)" } ?? ""
        return "type=\(focus.elementType.rawValue) id='\(focus.identifier)' label='\(focus.label)' x=\(Int(focus.frame.minX)) y=\(Int(focus.frame.minY))\(symbol)"
    }

    /// Remaining seconds shown for the clip on the shelf ("9:40 remaining",
    /// the first "remaining" text after the clip's title).
    private func clipRemainingSeconds() -> Int? {
        let texts = shelfTexts()
        guard let index = texts.firstIndex(where: { $0.contains(clipTitle) }) else { return nil }
        guard let text = texts[(index + 1)...].prefix(4).first(where: { $0.contains("remaining") }),
              let clock = text.split(separator: " ").first else { return nil }
        let parts = clock.split(separator: ":").compactMap { Int($0) }
        guard (2...3).contains(parts.count) else { return nil }
        return parts.reduce(0) { $0 * 60 + $1 }
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

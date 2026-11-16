// Unsigned, simulator-only evidence against the installed candidate app.
// XCTest is required for XCUIRemote. These tests never substitute mock renders
// or a fixture-reported setting for screenshots or actual focus assertions.
import XCTest

@MainActor
final class ThemeRemoteUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.seanjseymour.yatteeprofiles")
    private let remote = XCUIRemote.shared
    private var launcher: XCUIElement { app.buttons["viewerPicker.open"] }
    private var state: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "theme.validation.state").firstMatch
    }

    override func tearDownWithError() throws {
        capture("Final state - \(name)")
        print("FINAL ACCESSIBILITY TREE\n\(app.debugDescription)")
        app.terminate()
    }

    private func launch(items: Int, theme: String? = nil, mode: String? = nil,
                        settings: Bool = false, search: Bool = false, viewerName: String = "Alpha") {
        app.terminate()
        app.launchEnvironment = [
            "YATTEE_FOCUS_UI_ITEMS": String(items),
            "YATTEE_FOCUS_UI_SETTINGS": settings ? "1" : "0",
            "YATTEE_FOCUS_UI_SEARCH": search ? "1" : "0",
            "YATTEE_FOCUS_UI_VIEWER_NAME": viewerName
        ]
        if let theme { app.launchEnvironment["YATTEE_THEME"] = theme }
        if let mode { app.launchEnvironment["YATTEE_MODE"] = mode }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(launcher.waitForExistence(timeout: 30), app.debugDescription)
    }

    private func capture(_ title: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = title
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func focused(_ target: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasFocus == true"), object: target
        )], timeout: 5)
        XCTAssertEqual(result, .completed, app.debugDescription, file: file, line: line)
    }

    /// Setup navigation is bounded and uses only real remote commands. The
    /// tested Right/Left transitions below are one exact press each.
    private func focusContent(_ target: XCUIElement) {
        XCTAssertTrue(target.waitForExistence(timeout: 20), app.debugDescription)
        // Native tvOS sidebar may overlap content geometrically. Escape it
        // with Right, not frame comparisons. This is the proven original
        // focusInitialContent setup; assertions below still use exact presses.
        if !target.hasFocus {
            remote.press(launcher.hasFocus ? .left : .right)
        }
        for _ in 0..<6 {
            if target.hasFocus { break }
            if launcher.hasFocus { remote.press(.left) }
            else { remote.press(.down) }
        }
        focused(target)
    }

    @discardableResult
    private func reachViewer() -> Bool {
        if launcher.hasFocus { return true }
        for _ in 0..<3 {
            remote.press(.up)
            if launcher.hasFocus { return true }
            for _ in 0..<6 {
                remote.press(.right)
                if launcher.hasFocus { return true }
            }
        }
        return launcher.hasFocus
    }

    private func assertState(theme: String, mode: String, actual: String? = nil,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(state.waitForExistence(timeout: 5), app.debugDescription, file: file, line: line)
        let expected = actual.map { "\(theme)|\(mode)|\($0)" } ?? "\(theme)|\(mode)|"
        let predicate = actual == nil
            ? NSPredicate(format: "value BEGINSWITH %@ OR label BEGINSWITH %@", expected, expected)
            : NSPredicate(format: "value == %@ OR label == %@", expected, expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: state)], timeout: 5)
        XCTAssertEqual(result, .completed,
                       "Expected \(expected), got \(String(describing: state.value)); \(state.label)\n\(app.debugDescription)",
                       file: file, line: line)
    }

    // Each combination is its own capture test: a navigation failure cannot
    // prevent the other combinations from being captured by XCTest.
    func testCaptureHorizonLight() { captureCombination(theme: "horizon", mode: "light") }
    func testCaptureHorizonDark() { captureCombination(theme: "horizon", mode: "dark") }
    func testCaptureSlateLight() { captureCombination(theme: "slate", mode: "light") }
    func testCaptureSlateDark() { captureCombination(theme: "slate", mode: "dark") }

    private func captureCombination(theme: String, mode: String) {
        continueAfterFailure = true
        let label = "\(theme)-\(mode)"
        let longViewer = "Alexandria Catherine Seymour"
        for items in [0, 1, 5] {
            launch(items: items, theme: theme, mode: mode, viewerName: longViewer)
            capture("\(label) Home \(items) entries initial focus")
            let identifier = items == 0 ? "home.empty.browseSources"
                : (theme == "horizon" ? "home.horizon.resume" : "home.video.focus-fixture-0")
            focusContent(app.buttons[identifier])
            capture("\(label) Home \(items) entries content focused unobscured long Viewer")
        }
        launch(items: 1, theme: theme, mode: mode, search: true, viewerName: longViewer)
        capture("\(label) Search initial focus")
        focusContent(app.textFields.firstMatch)
        capture("\(label) Search field focused unobscured long Viewer")
        remote.press(.right)
        capture("\(label) Search options after Right long Viewer")
        launch(items: 1, theme: theme, mode: mode, settings: true, viewerName: longViewer)
        capture("\(label) Settings initial focus")
        focusContent(app.cells["Sources"])
        capture("\(label) Settings content focused unobscured long Viewer")
        // Save the root capture even if navigation to the picker fails.
        let reached = reachViewer()
        capture("\(label) Settings after Viewer navigation")
        if reached {
            remote.press(.select)
            let alpha = app.buttons[longViewer]
            let opened = alpha.waitForExistence(timeout: 5)
            capture("\(label) Viewer picker")
            XCTAssertTrue(opened, app.debugDescription)
            if opened {
                remote.press(.right)
                capture("\(label) Viewer Rename focused")
                remote.press(.select)
                _ = app.alerts.firstMatch.waitForExistence(timeout: 5)
                capture("\(label) Viewer editor")
                remote.press(.menu)
                remote.press(.menu)
            }
        }
        XCTAssertTrue(reached, "Viewer must be reachable for \(label)\n\(app.debugDescription)")
        // State assertion happens after the captures, not before them.
        launch(items: 1, theme: theme, mode: mode)
        assertState(theme: theme, mode: mode, actual: mode)
    }

    func testHorizonSingleItemRightViewerLeftReturns() { checkSingleItem(theme: "horizon") }
    func testSlateSingleItemRightViewerLeftReturns() { checkSingleItem(theme: "slate") }

    private func checkSingleItem(theme: String) {
        continueAfterFailure = false
        launch(items: 1, theme: theme, mode: "dark")
        let tile = app.buttons[theme == "horizon" ? "home.horizon.resume" : "home.video.focus-fixture-0"]
        focusContent(tile)
        capture("\(theme) single item before Right")
        remote.press(.right)
        capture("\(theme) single item after Right")
        focused(launcher)
        remote.press(.left)
        capture("\(theme) single item after Left")
        focused(tile)
    }

    func testSlateGridVisitsAdjacentCardBeforeViewer() {
        continueAfterFailure = false
        launch(items: 5, theme: "slate", mode: "dark")
        let first = app.buttons["home.video.focus-fixture-0"]
        let second = app.buttons["home.video.focus-fixture-1"]
        focusContent(first)
        remote.press(.right)
        capture("Slate five entries after first Right")
        focused(second)
        remote.press(.left)
        focused(first)
    }

    func testSettingsAppearanceDetailAndBack() {
        continueAfterFailure = false
        launch(items: 0, theme: "horizon", mode: "light", settings: true)
        let appearance = app.cells["Appearance"]
        focusContent(appearance)
        remote.press(.select)
        let theme = app.descendants(matching: .any).matching(identifier: "appearance.tvTheme").firstMatch
        let mode = app.descendants(matching: .any).matching(identifier: "appearance.tvMode").firstMatch
        XCTAssertTrue(theme.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(mode.exists, app.debugDescription)
        capture("Appearance settings Theme and Mode pickers")
        remote.press(.menu)
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertTrue(appearance.exists, "Back must return one level to Settings")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Match a native picker's focusable wrapper, not an assumed element type.
    /// The identifiers were observed in the previous run; option labels are
    /// verified present in each freshly printed accessibility snapshot.
    private func pickerControl(_ identifier: String) -> XCUIElement {
        let cells = app.cells.containing(.any, identifier: identifier)
        if cells.firstMatch.exists { return cells.firstMatch }
        let buttons = app.buttons.matching(identifier: identifier)
        if buttons.firstMatch.exists { return buttons.firstMatch }
        return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func moveFocus(to target: XCUIElement, maxPresses: Int = 12) {
        XCTAssertTrue(target.waitForExistence(timeout: 5), app.debugDescription)
        for _ in 0..<maxPresses {
            if target.hasFocus { return }
            let current = app.descendants(matching: .any)
                .matching(NSPredicate(format: "hasFocus == true")).firstMatch
            guard current.exists else { XCTFail("No native focus\n\(app.debugDescription)"); return }
            if target.frame.midY < current.frame.minY { remote.press(.up) }
            else if target.frame.midY > current.frame.maxY { remote.press(.down) }
            else if target.frame.midX < current.frame.midX { remote.press(.left) }
            else { remote.press(.right) }
        }
        focused(target)
    }

    private func choosePicker(_ identifier: String, option: String) {
        let control = pickerControl(identifier)
        moveFocus(to: control)
        remote.press(.select)
        print("OPEN PICKER \(identifier)\n\(app.debugDescription)")
        let exactLabel = NSPredicate(format: "label == %@", option)
        let optionElement = app.descendants(matching: .any).matching(exactLabel).firstMatch
        XCTAssertTrue(optionElement.waitForExistence(timeout: 5), app.debugDescription)
        // Native tvOS can focus the cell that wraps its text. Choose using
        // the observed focused element/descendant relationship, not .buttons.
        var selected = false
        for _ in 0..<12 {
            let current = app.descendants(matching: .any)
                .matching(NSPredicate(format: "hasFocus == true")).firstMatch
            guard current.exists else { break }
            if current.label == option || current.descendants(matching: .any).matching(exactLabel).firstMatch.exists {
                remote.press(.select)
                selected = true
                break
            }
            if optionElement.frame.midY < current.frame.minY { remote.press(.up) }
            else if optionElement.frame.midY > current.frame.maxY { remote.press(.down) }
            else if optionElement.frame.midX < current.frame.midX { remote.press(.left) }
            else { remote.press(.right) }
        }
        XCTAssertTrue(selected, "Could not focus/select observed option \(option)\n\(app.debugDescription)")
        print("AFTER PICKER \(identifier) selected \(option)\n\(app.debugDescription)")
        capture("Settings selected \(option)")
        XCTAssertTrue(pickerControl(identifier).waitForExistence(timeout: 5), "Picker must return to Appearance\n\(app.debugDescription)")
    }

    private func openAppearance() {
        let appearance = app.cells["Appearance"]
        focusContent(appearance)
        remote.press(.select)
        XCTAssertTrue(pickerControl("appearance.tvTheme").waitForExistence(timeout: 5), app.debugDescription)
        print("APPEARANCE CONTROLS\n\(app.debugDescription)")
    }

    private func assertWindowAppearance(mode: String) {
        let probe = app.descendants(matching: .any).matching(identifier: "theme.validation.window").firstMatch
        XCTAssertTrue(probe.waitForExistence(timeout: 5), app.debugDescription)
        let matches = NSPredicate { _, _ in
            guard let raw = probe.value as? String else { return false }
            let pieces = raw.split(separator: "|").map(String.init)
            guard pieces.count == 3, ["light", "dark"].contains(pieces[2]) else { return false }
            let actual = (self.state.value as? String)?.split(separator: "|").last.map(String.init)
            if mode == "system" {
                return pieces[0] == "unspecified" && pieces[1] == pieces[2] && actual == pieces[1]
            }
            return pieces[0] == mode && pieces[1] == mode && actual == mode
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: matches, object: probe)], timeout: 5), .completed,
                       "Actual window probe: \(String(describing: probe.value)); SwiftUI: \(String(describing: state.value))\n\(app.debugDescription)")
        print("WINDOW APPEARANCE \(String(describing: probe.value)); SWIFTUI \(String(describing: state.value))")
    }

    func testSettingsSelectionsSystemResetAndRelaunch() {
        continueAfterFailure = false
        launch(items: 1, theme: "horizon", mode: "light", settings: true)
        openAppearance()
        choosePicker("appearance.tvTheme", option: "Slate")
        choosePicker("appearance.tvMode", option: "Dark")
        remote.press(.menu)
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), app.debugDescription)
        assertState(theme: "slate", mode: "dark", actual: "dark")
        assertWindowAppearance(mode: "dark")
        capture("Actual Settings choices immediately applied")
        launch(items: 1, settings: true) // No theme/mode fixture seeds.
        assertState(theme: "slate", mode: "dark", actual: "dark")
        assertWindowAppearance(mode: "dark")

        openAppearance()
        choosePicker("appearance.tvMode", option: "System")
        remote.press(.menu)
        assertState(theme: "slate", mode: "system")
        assertWindowAppearance(mode: "system")
        capture("Settings Dark to System removes actual window override")
        launch(items: 1, settings: true)
        assertState(theme: "slate", mode: "system")
        assertWindowAppearance(mode: "system")

        openAppearance()
        choosePicker("appearance.tvMode", option: "Light")
        remote.press(.menu)
        assertState(theme: "slate", mode: "light", actual: "light")
        assertWindowAppearance(mode: "light")
        openAppearance()
        choosePicker("appearance.tvMode", option: "System")
        remote.press(.menu)
        assertState(theme: "slate", mode: "system")
        assertWindowAppearance(mode: "system")
        capture("Settings Light to System removes actual window override")
        print("System reset/current scene inheritance verified; a live OS appearance toggle was NOT exercised.")

        // The real picker must not expose Alpha's existing progress to Beta.
        // This is UI/history interaction, not a claim that network playback ran.
        launch(items: 1) // Saved Slate/System; isolated Alpha history only.
        assertState(theme: "slate", mode: "system")
        XCTAssertTrue(reachViewer(), app.debugDescription)
        remote.press(.select)
        let beta = app.buttons["Beta"]
        moveFocus(to: beta)
        remote.press(.select)
        XCTAssertTrue(app.buttons["home.empty.browseSources"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.buttons["home.video.focus-fixture-0"].exists, "Beta must not inherit Alpha's progress")
        assertState(theme: "slate", mode: "system")
        assertWindowAppearance(mode: "system")
        capture("Saved theme and System mode with Beta empty history")
        XCTAssertTrue(reachViewer(), app.debugDescription)
        remote.press(.select)
        moveFocus(to: app.buttons["Alpha"])
        remote.press(.select)
        XCTAssertTrue(app.buttons["home.video.focus-fixture-0"].waitForExistence(timeout: 10), app.debugDescription)
        assertState(theme: "slate", mode: "system")
        capture("Return to Alpha restores its progress without changing appearance")
    }

    func testSearchFocusedAndUnfocusedContrastRegression() {
        continueAfterFailure = false
        for theme in ["horizon", "slate"] {
            for mode in ["light", "dark"] {
                for name in ["Alpha", "Alexandria Catherine Seymour"] {
                    let label = "Search-\(theme)-\(mode)-\(name)"
                    launch(items: 0, theme: theme, mode: mode, search: true, viewerName: name)
                    let options = app.buttons["View Options"]
                    focusContent(app.textFields.firstMatch)
                    capture("\(label) field focused Options unfocused")
                    remote.press(.right)
                    focused(options)
                    XCTAssertLessThan(launcher.frame.maxY + 12, options.frame.minY)
                    capture("\(label) Options focused")
                    remote.press(.right)
                    focused(launcher)
                    XCTAssertLessThan(launcher.frame.maxY + 12, options.frame.minY)
                    XCTAssertLessThanOrEqual(launcher.frame.maxX, app.frame.maxX)
                    capture("\(label) Viewer focused Options unfocused")
                    remote.press(.select)
                    focused(app.buttons[name])
                    remote.press(.menu)
                    focused(launcher)
                    remote.press(.left)
                    focused(options)
                    remote.press(.select)
                    capture("\(label) Options presented")
                    remote.press(.menu)
                    focused(options)
                    assertState(theme: theme, mode: mode, actual: mode)
                    capture("\(label) Options focused after Back")
                }
            }
        }
    }

    func testPickerRenameDownAddCancelAndReturn() {
        continueAfterFailure = false
        launch(items: 1, theme: "horizon", mode: "light")
        XCTAssertTrue(reachViewer(), app.debugDescription)
        remote.press(.select)
        let alpha = app.buttons["Alpha"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), app.debugDescription)
        focused(alpha)
        remote.press(.right)
        let renames = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'viewerPicker.rename.'")).allElementsBoundByIndex
        XCTAssertEqual(renames.count, 2, app.debugDescription)
        focused(renames[0])
        remote.press(.down)
        focused(renames[1])
        remote.press(.down)
        focused(app.buttons["viewerPicker.add"])
        remote.press(.select)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        capture("Light picker Add editor")
        remote.press(.menu)
        focused(app.buttons["viewerPicker.add"])
        remote.press(.menu)
        focused(launcher)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSettingsBackStaysInApp() {
        continueAfterFailure = false
        launch(items: 0, theme: "slate", mode: "light", settings: true)
        XCTAssertTrue(reachViewer(), app.debugDescription)
        focused(launcher)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Alpha"].waitForExistence(timeout: 5), app.debugDescription)
        remote.press(.menu)
        focused(launcher)
        XCTAssertTrue(app.cells["Appearance"].exists, "Picker Back must retain Settings\n\(app.debugDescription)")
        remote.press(.menu)
        XCTAssertTrue(app.buttons["home.empty.browseSources"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testIndependentPreferencesPersistAcrossRelaunch() {
        continueAfterFailure = false
        for theme in ["horizon", "slate"] {
            for mode in ["light", "dark", "system"] {
                launch(items: 1, theme: theme, mode: mode)
                assertState(theme: theme, mode: mode, actual: mode == "system" ? nil : mode)
                launch(items: 1) // No preference seed on the second launch.
                assertState(theme: theme, mode: mode, actual: mode == "system" ? nil : mode)
            }
        }
        launch(items: 1, theme: "horizon", mode: "light")
        launch(items: 1, theme: "slate") // Change theme only.
        assertState(theme: "slate", mode: "light", actual: "light")
        launch(items: 1, mode: "dark") // Change mode only.
        assertState(theme: "slate", mode: "dark", actual: "dark")
        launch(items: 1, mode: "system")
        assertState(theme: "slate", mode: "system")
        capture("System mode reports current inherited appearance")
        print("LIVE OS SWITCHING: not exercised; actual Settings reset and current window/scene inheritance are checked separately.")
    }
}

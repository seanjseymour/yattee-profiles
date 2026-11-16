// Real remote events against the installed, unsigned app. XCTest is required
// for XCUIRemote; production model tests continue to use Swift Testing.
import XCTest

@MainActor
final class ViewerRemoteUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.seanjseymour.yatteeprofiles")
    private let remote = XCUIRemote.shared
    private var launcher: XCUIElement { app.buttons["viewerPicker.open"] }

    override func tearDownWithError() throws {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
        print("FINAL ACCESSIBILITY TREE\n\(app.debugDescription)")
        app.terminate()
    }

    private func launch(items: Int, settings: Bool = false) {
        continueAfterFailure = false
        app.launchEnvironment["YATTEE_FOCUS_UI_ITEMS"] = String(items)
        app.launchEnvironment["YATTEE_FOCUS_UI_SETTINGS"] = settings ? "1" : "0"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(launcher.waitForExistence(timeout: 30), app.debugDescription)
    }

    private func focused(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasFocus == true"), object: element
        )], timeout: 5)
        XCTAssertEqual(result, .completed, app.debugDescription, file: file, line: line)
    }

    private func focusInitialContent(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), app.debugDescription)
        if !element.hasFocus {
            remote.press(launcher.hasFocus ? .left : .right)
        }
        for _ in 0..<6 {
            if element.hasFocus { break }
            if launcher.hasFocus { remote.press(.left) }
            else { remote.press(.down) }
        }
        focused(element)
    }

    func testSingleContinueWatchingTileReachesViewerAndPicker() {
        launch(items: 1)
        let tile = app.buttons["home.video.focus-fixture-0"]
        focusInitialContent(tile)
        remote.press(.right)
        focused(launcher)
        remote.press(.left)
        focused(tile)
        remote.press(.right)
        focused(launcher)
        remote.press(.select)
        let alpha = app.buttons["Alpha"]
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), app.debugDescription)
        focused(alpha)
        // Preserve build 282's one-row-to-Add path, with two fixture viewers.
        remote.press(.right)
        let rename = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'viewerPicker.rename.'")).allElementsBoundByIndex
        XCTAssertEqual(rename.count, 2)
        focused(rename[0])
        remote.press(.down)
        focused(rename[1])
        remote.press(.down)
        focused(app.buttons["viewerPicker.add"])
        remote.press(.select)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        remote.press(.menu)
        focused(app.buttons["viewerPicker.add"])
        XCTAssertEqual(app.state, .runningForeground)
        remote.press(.menu)
        focused(launcher)
        XCTAssertEqual(app.state, .runningForeground)
        // Select a different viewer and reopen: selection and focus must agree.
        remote.press(.select)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5))
        focused(alpha)
        remote.press(.down)
        focused(app.buttons["Beta"])
        remote.press(.select)
        focused(launcher)
        XCTAssertTrue(launcher.label.contains("Beta"))
        remote.press(.select)
        focused(app.buttons["Beta"])
        remote.press(.menu)
        focused(launcher)
    }

    func testRightVisitsNextTileBeforeViewerAndLeftReturns() {
        launch(items: 2)
        let first = app.buttons["home.video.focus-fixture-0"]
        let second = app.buttons["home.video.focus-fixture-1"]
        focusInitialContent(first)
        remote.press(.right)
        focused(second)
        remote.press(.right)
        focused(launcher)
        remote.press(.left)
        focused(second)
        remote.press(.left)
        focused(first)
    }

    func testEmptyHomeCanReachViewerAndReturn() {
        launch(items: 0)
        let sources = app.buttons["home.empty.openSources"]
        focusInitialContent(sources)
        remote.press(.right)
        focused(launcher)
        remote.press(.left)
        focused(sources)
    }

    func testSettingsDetailBackAndLauncherBackStayInApp() {
        launch(items: 0, settings: true)
        let appearance = app.buttons["Appearance"]
        // Settings uses native navigation links; some OS versions expose them
        // as cells. Query all descendants by label if necessary.
        let row = appearance.exists ? appearance : app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Appearance'")).firstMatch
        focusInitialContent(row)
        remote.press(.select)
        let hidden = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: launcher)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 5), .completed, app.debugDescription)
        remote.press(.menu)
        XCTAssertTrue(launcher.waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground)
        remote.press(.right)
        focused(launcher)
        remote.press(.select)
        XCTAssertTrue(app.buttons["Alpha"].waitForExistence(timeout: 5))
        remote.press(.menu)
        focused(launcher)
        XCTAssertTrue(row.exists, "Picker Back must stay on Settings")
        remote.press(.menu)
        XCTAssertTrue(app.buttons["home.empty.openSources"].waitForExistence(timeout: 5), app.debugDescription)
        XCTAssertEqual(app.state, .runningForeground)
    }
}

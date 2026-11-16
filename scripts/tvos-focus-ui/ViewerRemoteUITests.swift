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

    private func launch(items: Int, settings: Bool = false, search: Bool = false, sources: Bool = false, viewerName: String = "Alpha") {
        continueAfterFailure = false
        app.launchEnvironment["YATTEE_FOCUS_UI_ITEMS"] = String(items)
        app.launchEnvironment["YATTEE_FOCUS_UI_SETTINGS"] = settings ? "1" : "0"
        app.launchEnvironment["YATTEE_FOCUS_UI_SEARCH"] = search ? "1" : "0"
        app.launchEnvironment["YATTEE_FOCUS_UI_SOURCES"] = sources ? "1" : "0"
        app.launchEnvironment["YATTEE_FOCUS_UI_VIEWER_NAME"] = viewerName
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

    func testSearchHeaderAndOptionsBoundary() {
        checkSearchControls(viewerName: "Alpha")
    }

    func testSearchLongViewerNameKeepsAlignmentAndReachability() {
        checkSearchControls(viewerName: "Alexandria Catherine Seymour")
    }

    private func checkSearchControls(viewerName: String) {
        launch(items: 0, search: true, viewerName: viewerName)
        let options = app.buttons["View Options"]
        focusInitialContent(options)
        XCTAssertLessThan(launcher.frame.maxY + 12, options.frame.minY)
        let unfocused = XCTAttachment(screenshot: app.screenshot())
        unfocused.name = "Search — Viewer unfocused"
        unfocused.lifetime = .keepAlways
        add(unfocused)
        remote.press(.right)
        focused(launcher)
        XCTAssertLessThan(launcher.frame.maxY + 12, options.frame.minY)
        XCTAssertTrue(launcher.label.contains(viewerName))
        XCTAssertLessThanOrEqual(launcher.frame.maxX, app.frame.maxX)
        let focusedCapture = XCTAttachment(screenshot: app.screenshot())
        focusedCapture.name = "Search — Viewer focused"
        focusedCapture.lifetime = .keepAlways
        add(focusedCapture)
        remote.press(.select)
        focused(app.buttons[viewerName])
        remote.press(.menu)
        focused(launcher)
        remote.press(.left)
        focused(options)
        remote.press(.select)
        capture("Search — View Options presented")
        remote.press(.menu)
        focused(options)
    }

    private func capture(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testSettingsRootHeaderSeparation() {
        launch(items: 0, settings: true)
        let sourceRow = app.cells["Sources"]
        focusInitialContent(sourceRow)
        capture("Settings — Sources focused")
        XCTAssertLessThan(launcher.frame.maxY + 12, sourceRow.frame.minY)
        remote.press(.right)
        focused(launcher)
        capture("Settings — Viewer focused")
        XCTAssertLessThan(launcher.frame.maxY + 12, sourceRow.frame.minY)
        remote.press(.left)
        focused(sourceRow)
    }

    func testSourcesRootHeader() {
        launch(items: 0, sources: true)
        capture("Sources — root")
    }

    func testFiveTilesKeepNativeTraversalBeforeViewer() {
        launch(items: 5)
        focusInitialContent(app.buttons["home.video.focus-fixture-0"])
        for index in 1..<5 {
            remote.press(.right)
            focused(app.buttons["home.video.focus-fixture-\(index)"])
        }
        remote.press(.right)
        focused(launcher)
        capture("Home — five tiles, Viewer focused")
    }

    func testSettingsDetailBackAndLauncherBackStayInApp() {
        launch(items: 0, settings: true)
        // tvOS List focuses the cell, not the NavigationLink's child button.
        // Querying the child always reports hasFocus=false and walks past it.
        let row = app.cells["Appearance"]
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

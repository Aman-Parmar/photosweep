import XCTest

/// App Store screenshot lane — 7 shots on the iPhone 17 Pro Max simulator.
/// Real simulator screenshots of the real app, never mockups. The app runs
/// in `--screenshot-mode`: the scan result is the fixed synthetic sample
/// (no real photos, no network) and thumbnails are programmatically
/// generated images. No PhotoKit access is needed in this lane.
///
/// CI runs this lane in parallel with the unit-test lane (see
/// .github/workflows/ios.yml) and uploads the PNGs as an artifact.
/// After a run, check framing: scan button, group rows, keeper badge and
/// paywall prices fully visible in each shot, no clipping.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
    }

    // MARK: - 01 Home scan

    func test01HomeScan() {
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.staticTexts["reclaimable-total"].waitForExistence(timeout: 10))
        saveScreenshot(named: "01-home-scan")
    }

    // MARK: - 02 Duplicates group review

    func test02DuplicatesGroupReview() {
        app.tabBars.buttons["Results"].tap()
        let row = app.buttons["results-group-duplicates-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["group-delete-button"].waitForExistence(timeout: 10))
        saveScreenshot(named: "02-duplicates-review")
    }

    // MARK: - 03 Similar group review

    func test03SimilarGroupReview() {
        app.tabBars.buttons["Results"].tap()
        let row = app.buttons["results-group-similar-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["group-delete-button"].waitForExistence(timeout: 10))
        saveScreenshot(named: "03-similar-review")
    }

    // MARK: - 04 Blurry group review

    func test04BlurryGroupReview() {
        app.tabBars.buttons["Results"].tap()
        let row = app.buttons["results-group-blurry-0"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["group-delete-button"].waitForExistence(timeout: 10))
        saveScreenshot(named: "04-blurry-review")
    }

    // MARK: - 05 Screenshots

    func test05Screenshots() {
        app.tabBars.buttons["Screenshots"].tap()
        XCTAssertTrue(app.navigationBars["Screenshots"].waitForExistence(timeout: 10))
        saveScreenshot(named: "05-screenshots")
    }

    // MARK: - 06 Large videos

    func test06LargeVideos() {
        app.tabBars.buttons["Videos"].tap()
        XCTAssertTrue(app.navigationBars["Large Videos"].waitForExistence(timeout: 10))
        saveScreenshot(named: "06-large-videos")
    }

    // MARK: - 07 Paywall

    func test07Paywall() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-get-pro-button"].tap()
        XCTAssertTrue(app.staticTexts["PhotoSweep Pro"].waitForExistence(timeout: 10))
        saveScreenshot(named: "07-paywall")
    }

    // MARK: - Helper

    /// Saves the screenshot both as an XCTAttachment (in the xcresult) and
    /// as a PNG in /tmp/photosweep-screenshots, which CI uploads as an
    /// artifact. The simulator shares the host /tmp, so this path works.
    private func saveScreenshot(named name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let dir = URL(fileURLWithPath: "/tmp/photosweep-screenshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

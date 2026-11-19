import XCTest

/// App Store screenshot lane — 12 shots on the iPhone 17 Pro Max simulator.
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
        // The "How it works" steps are one line each so the whole
        // section fits above the floating tab bar at rest: no scroll,
        // because scrolling ghosts the header under the translucent
        // nav bar (QA FAIL on b3f66d2). Fail loudly if a step is ever
        // covered again instead of silently capturing a cut shot.
        let step3 = app.staticTexts["how-it-works-step-3"]
        XCTAssertTrue(step3.waitForExistence(timeout: 10))
        XCTAssertTrue(step3.isHittable, "How it works step 3 should clear the tab bar")
        saveScreenshot(named: "01-home-scan")
    }

    // MARK: - 02 Duplicates group review

    func test02DuplicatesGroupReview() {
        app.tabBars.buttons["Results"].tap()
        openGroup(rowID: "results-group-duplicates-0")
        saveScreenshot(named: "02-duplicates-review")
    }

    // MARK: - 03 Similar group review

    func test03SimilarGroupReview() {
        app.tabBars.buttons["Results"].tap()
        openGroup(rowID: "results-group-similar-0")
        saveScreenshot(named: "03-similar-review")
    }

    // MARK: - 04 Blurry group review

    func test04BlurryGroupReview() {
        app.tabBars.buttons["Results"].tap()
        openGroup(rowID: "results-group-blurry-0")
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

    // MARK: - 08 Compare with keeper

    /// The compare sheet: a non-keeper burst frame side by side with
    /// the keeper. Listing shot 8; it proves the v1.2 compare feature
    /// renders.
    func test08Compare() {
        app.tabBars.buttons["Results"].tap()
        openGroup(rowID: "results-group-similar-0")
        let compareButton = app.buttons["group-compare-sample-burst-1"]
        XCTAssertTrue(compareButton.waitForExistence(timeout: 10))
        compareButton.tap()
        XCTAssertTrue(app.buttons["compare-keep-button"].waitForExistence(timeout: 10))
        saveScreenshot(named: "08-compare")
    }

    // MARK: - 09 Video compression

    /// The compress sheet for the largest sample video: three presets
    /// with before/after estimates, then the simulated run to its done
    /// state. Screenshot mode simulates the export (no real library),
    /// so this captures the real sheet UI end to end. Listing shot 9;
    /// it proves the PS-1 video compression feature renders.
    func test09VideoCompress() {
        app.tabBars.buttons["Videos"].tap()
        let compressButton = app.buttons["video-compress-button-sample-video-0"]
        XCTAssertTrue(compressButton.waitForExistence(timeout: 10))
        compressButton.tap()
        XCTAssertTrue(app.staticTexts["Compress video"].waitForExistence(timeout: 10))
        let startButton = app.buttons["compress-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()
        XCTAssertTrue(app.staticTexts["compress-done-label"].waitForExistence(timeout: 15))
        saveScreenshot(named: "09-video-compress")
    }

    // MARK: - 10 Live Photo to still

    /// The convert sheet for the largest sample Live Photo: original
    /// and still sizes with the saving estimate, then the simulated
    /// run to its done state. Screenshot mode simulates the
    /// conversion (no real library), so this captures the real sheet
    /// UI end to end. Listing shot 10; it proves the PS-3 Live Photo
    /// conversion renders.
    func test10LivePhotoConvert() {
        app.tabBars.buttons["Scan"].tap()
        let card = app.buttons["home-category-livephotos"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.navigationBars["Live Photos"].waitForExistence(timeout: 10))
        let convertButton = app.buttons["livephoto-convert-button-sample-live-0"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: 10))
        convertButton.tap()
        XCTAssertTrue(app.staticTexts["Convert to still"].waitForExistence(timeout: 10))
        let startButton = app.buttons["livephoto-convert-start-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 10))
        startButton.tap()
        XCTAssertTrue(app.staticTexts["livephoto-convert-done-label"].waitForExistence(timeout: 15))
        saveScreenshot(named: "10-live-photo-convert")
    }

    // MARK: - 11 Swipe deck

    /// The swipe deck for the sample's newest month (October 2025,
    /// 4 screenshot cards): month header, card, and progress label,
    /// then one Keep tap advances the progress and the next card.
    /// Listing shot 11; it proves the swipe-mode deck renders.
    func test11SwipeDeck() {
        app.tabBars.buttons["Scan"].tap()
        let card = app.buttons["home-swipe-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        let monthRow = app.buttons["swipe-month-2025-10"]
        XCTAssertTrue(monthRow.waitForExistence(timeout: 10))
        monthRow.tap()
        XCTAssertTrue(app.staticTexts["swipe-month-label"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["swipe-card-kind"].waitForExistence(timeout: 10))
        let progress = app.staticTexts["swipe-progress-label"]
        XCTAssertTrue(progress.waitForExistence(timeout: 10))
        XCTAssertEqual(progress.label, "0 of 4 reviewed")
        app.buttons["swipe-keep-button"].tap()
        // The label updates asynchronously after the tap: wait for
        // the new value instead of asserting on a possibly stale read.
        let updated = NSPredicate(format: "label == %@", "1 of 4 reviewed")
        expectation(for: updated, evaluatedWith: progress)
        waitForExpectations(timeout: 10)
        XCTAssertTrue(app.staticTexts["swipe-card-kind"].waitForExistence(timeout: 10))
        saveScreenshot(named: "11-swipe-deck")
    }

    // MARK: - 12 Swipe month complete

    /// Decide every card in the sample's newest month (October 2025,
    /// 4 screenshot cards) for deletion: finishing the month opens
    /// the summary sheet, confirming deletes the batch and shows the
    /// month-done state. Listing shot 12; it proves the swipe-mode
    /// commit flow renders end to end.
    func test12SwipeMonthComplete() {
        app.tabBars.buttons["Scan"].tap()
        let card = app.buttons["home-swipe-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        let monthRow = app.buttons["swipe-month-2025-10"]
        XCTAssertTrue(monthRow.waitForExistence(timeout: 10))
        monthRow.tap()
        XCTAssertTrue(app.staticTexts["swipe-progress-label"].waitForExistence(timeout: 10))
        for _ in 0..<4 {
            let deleteButton = app.buttons["swipe-delete-button"]
            XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
            deleteButton.tap()
        }
        // The four decisions must have registered before the sheet
        // can open: wait for the progress value, so a mutation
        // failure fails here with the cause named instead of as a
        // missing commit button (CI run 44450339524).
        let progress = app.staticTexts["swipe-progress-label"]
        let complete = NSPredicate(format: "label == %@", "4 of 4 reviewed")
        expectation(for: complete, evaluatedWith: progress)
        waitForExpectations(timeout: 10)
        // Finishing the month opens the summary sheet: the commit
        // button inside it is the proof the sheet is up (a
        // NavigationStack identifier is not reliably queryable).
        let commitButton = app.buttons["swipe-commit-button"]
        XCTAssertTrue(commitButton.waitForExistence(timeout: 10))
        XCTAssertEqual(commitButton.label, "Delete 4 photos")
        commitButton.tap()
        XCTAssertTrue(app.staticTexts["swipe-month-complete"].waitForExistence(timeout: 10))
        saveScreenshot(named: "12-swipe-month-complete")
    }

    // MARK: - Helper

    /// Opens a group from the Results list and waits for the review
    /// screen's delete button. The row tap is retried once: on the
    /// slow CI simulator the first tap can land while the list is
    /// still settling (run 44240431584: test04's row took ~9s to
    /// appear and the tap missed navigation, so the delete button
    /// never appeared). A missed tap leaves the row on screen, so a
    /// second tap is safe; a successful tap removes the row, so the
    /// retry is skipped.
    private func openGroup(rowID: String) {
        let row = app.buttons[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        if !app.buttons["group-delete-button"].waitForExistence(timeout: 5),
           row.waitForExistence(timeout: 2) {
            row.tap()
        }
        XCTAssertTrue(app.buttons["group-delete-button"].waitForExistence(timeout: 10))
    }

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

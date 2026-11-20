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

    /// Default wait for a UI element to appear in the screenshot lane.
    /// One source so the 30 waits cannot drift apart.
    private let defaultWaitTimeout: TimeInterval = 10

    /// Longer wait for the compress/convert done labels, which appear
    /// only after a simulated job finishes. The 15-second row wait in
    /// openGroup stays a literal: it is a slow-simulator allowance,
    /// not a job-done wait.
    private let jobDoneWaitTimeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--screenshot-mode"]
        app.launch()
    }

    // MARK: - 01 Home scan

    func test01HomeScan() {
        app.tabBars.buttons["Scan"].tap()
        XCTAssertTrue(app.staticTexts["reclaimable-total"].waitForExistence(timeout: defaultWaitTimeout))
        // The "How it works" steps are one line each so the whole
        // section fits above the floating tab bar at rest: no scroll,
        // because scrolling ghosts the header under the translucent
        // nav bar (QA FAIL on b3f66d2). Fail loudly if a step is ever
        // covered again instead of silently capturing a cut shot.
        let step3 = app.staticTexts["how-it-works-step-3"]
        XCTAssertTrue(step3.waitForExistence(timeout: defaultWaitTimeout))
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
        XCTAssertTrue(app.navigationBars["Screenshots"].waitForExistence(timeout: defaultWaitTimeout))
        saveScreenshot(named: "05-screenshots")
    }

    // MARK: - 06 Large videos

    func test06LargeVideos() {
        app.tabBars.buttons["Videos"].tap()
        XCTAssertTrue(app.navigationBars["Large Videos"].waitForExistence(timeout: defaultWaitTimeout))
        saveScreenshot(named: "06-large-videos")
    }

    // MARK: - 07 Paywall

    func test07Paywall() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["settings-get-pro-button"].tap()
        XCTAssertTrue(app.staticTexts["PhotoSweep Pro"].waitForExistence(timeout: defaultWaitTimeout))
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
        XCTAssertTrue(compareButton.waitForExistence(timeout: defaultWaitTimeout))
        compareButton.tap()
        XCTAssertTrue(app.buttons["compare-keep-button"].waitForExistence(timeout: defaultWaitTimeout))
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
        XCTAssertTrue(compressButton.waitForExistence(timeout: defaultWaitTimeout))
        compressButton.tap()
        XCTAssertTrue(app.staticTexts["Compress video"].waitForExistence(timeout: defaultWaitTimeout))
        runSheetToDone(
            startButtonID: "compress-start-button",
            doneLabelID: "compress-done-label",
            screenshotName: "09-video-compress"
        )
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
        XCTAssertTrue(card.waitForExistence(timeout: defaultWaitTimeout))
        card.tap()
        XCTAssertTrue(app.navigationBars["Live Photos"].waitForExistence(timeout: defaultWaitTimeout))
        let convertButton = app.buttons["livephoto-convert-button-sample-live-0"]
        XCTAssertTrue(convertButton.waitForExistence(timeout: defaultWaitTimeout))
        convertButton.tap()
        XCTAssertTrue(app.staticTexts["Convert to still"].waitForExistence(timeout: defaultWaitTimeout))
        runSheetToDone(
            startButtonID: "livephoto-convert-start-button",
            doneLabelID: "livephoto-convert-done-label",
            screenshotName: "10-live-photo-convert"
        )
    }

    // MARK: - 11 Swipe deck

    /// The swipe deck for the sample's newest month (October 2025,
    /// 4 screenshot cards): month header, card, and progress label,
    /// then one Keep tap advances the progress and the next card.
    /// Listing shot 11; it proves the swipe-mode deck renders.
    func test11SwipeDeck() {
        openSwipeMonth()
        XCTAssertTrue(app.staticTexts["swipe-month-label"].waitForExistence(timeout: defaultWaitTimeout))
        XCTAssertTrue(app.staticTexts["swipe-card-kind"].waitForExistence(timeout: defaultWaitTimeout))
        let progress = app.staticTexts["swipe-progress-label"]
        XCTAssertTrue(progress.waitForExistence(timeout: defaultWaitTimeout))
        XCTAssertEqual(progress.label, "0 of 4 reviewed")
        app.buttons["swipe-keep-button"].tap()
        // The label updates asynchronously after the tap: wait for
        // the new value instead of asserting on a possibly stale read.
        waitForProgressLabel("1 of 4 reviewed")
        XCTAssertTrue(app.staticTexts["swipe-card-kind"].waitForExistence(timeout: defaultWaitTimeout))
        saveScreenshot(named: "11-swipe-deck")
    }

    // MARK: - 12 Swipe month complete

    /// Decide every card in the sample's newest month (October 2025,
    /// 4 screenshot cards) for deletion: finishing the month opens
    /// the summary sheet, confirming deletes the batch and shows the
    /// month-done state. Listing shot 12; it proves the swipe-mode
    /// commit flow renders end to end.
    func test12SwipeMonthComplete() {
        openSwipeMonth()
        XCTAssertTrue(app.staticTexts["swipe-progress-label"].waitForExistence(timeout: defaultWaitTimeout))
        for _ in 0..<4 {
            let deleteButton = app.buttons["swipe-delete-button"]
            XCTAssertTrue(deleteButton.waitForExistence(timeout: defaultWaitTimeout))
            deleteButton.tap()
        }
        // The four decisions must have registered before the sheet
        // can open: wait for the progress value, so a mutation
        // failure fails here with the cause named instead of as a
        // missing commit button (CI run 44450339524).
        waitForProgressLabel("4 of 4 reviewed")
        // Finishing the month opens the summary sheet: the commit
        // button inside it is the proof the sheet is up (a
        // NavigationStack identifier is not reliably queryable).
        let commitButton = app.buttons["swipe-commit-button"]
        XCTAssertTrue(commitButton.waitForExistence(timeout: defaultWaitTimeout))
        XCTAssertEqual(commitButton.label, "Delete 4 photos")
        commitButton.tap()
        XCTAssertTrue(app.staticTexts["swipe-month-complete"].waitForExistence(timeout: defaultWaitTimeout))
        saveScreenshot(named: "12-swipe-month-complete")
    }

    // MARK: - Helper

    /// Runs a sheet's simulated job to its done state: tap the start
    /// button, wait for the done label, then capture the shot. Shared
    /// by test09 and test10 so the run-to-done steps cannot drift
    /// apart; the start button, done label, and shot name stay
    /// per-sheet.
    private func runSheetToDone(startButtonID: String, doneLabelID: String, screenshotName: String) {
        let startButton = app.buttons[startButtonID]
        XCTAssertTrue(startButton.waitForExistence(timeout: defaultWaitTimeout))
        startButton.tap()
        XCTAssertTrue(app.staticTexts[doneLabelID].waitForExistence(timeout: jobDoneWaitTimeout))
        saveScreenshot(named: screenshotName)
    }

    /// Waits for the swipe progress label to show the expected value
    /// ("1 of 4 reviewed", "4 of 4 reviewed"). Shared by test11 and
    /// test12 so the predicate wait cannot drift apart.
    private func waitForProgressLabel(_ expected: String) {
        let progress = app.staticTexts["swipe-progress-label"]
        let predicate = NSPredicate(format: "label == %@", expected)
        expectation(for: predicate, evaluatedWith: progress)
        waitForExpectations(timeout: defaultWaitTimeout)
    }

    /// Opens the swipe deck for the sample's newest month (October
    /// 2025): Scan tab, swipe card, month row. Shared by test11 and
    /// test12 so the entry steps cannot drift apart; the month id is
    /// the sample data's newest month, so it changes only if the
    /// sample data does.
    private func openSwipeMonth() {
        app.tabBars.buttons["Scan"].tap()
        let card = app.buttons["home-swipe-card"]
        XCTAssertTrue(card.waitForExistence(timeout: defaultWaitTimeout))
        card.tap()
        let monthRow = app.buttons["swipe-month-2025-10"]
        XCTAssertTrue(monthRow.waitForExistence(timeout: defaultWaitTimeout))
        monthRow.tap()
    }

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
        XCTAssertTrue(app.buttons["group-delete-button"].waitForExistence(timeout: defaultWaitTimeout))
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

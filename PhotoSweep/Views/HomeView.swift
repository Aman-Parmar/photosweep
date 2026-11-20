import SwiftUI

/// Large state icon size shared by the Home no-scan-yet empty state and
/// the swipe-mode month-done state. One source so both 56pt hero icons
/// stay the same size.
let largeStateIconSize: CGFloat = 56

/// Home / Scan tab: the scan button, the summary of the last scan, and
/// one card per category. In screenshot mode the sample result is
/// already loaded, so this screen is the 01 screenshot.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @State private var showingPaywall = false
    @State private var showingSwipeMode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    header
                    if let result = appState.result {
                        summaryCard(result)
                        swipeEntryCard
                        categoryCards(result)
                        if result.isPartialScan {
                            partialScanNotice(result)
                        }
                    } else {
                        noScanYet
                    }
                    howItWorks
                }
                .padding()
                // The iOS 26 tab bar floats over the scroll content, so
                // the last section needs clearance: without this the
                // "How it works" lines sit half-hidden behind the bar
                // in the 01 screenshot.
                .padding(.bottom, 96)
            }
            .navigationTitle("PhotoSweep")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(store.isPro ? "Pro ✓" : AppCopy.getPro) {
                        showingPaywall = true
                    }
                    .accessibilityIdentifier("home-get-pro-button")
                }
            }
            .paywallSheet(isPresented: $showingPaywall)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Free up storage, honestly.")
                .font(.title2.bold())
            Text("Finds duplicates, similar shots, blurry photos, screenshots, large videos and Live Photos, on your phone, nothing uploaded. You review everything before anything is deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var noScanYet: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: largeStateIconSize))
                .foregroundStyle(.secondary)
            Text("Your library hasn't been scanned yet.")
                .font(.headline)
            scanButton
            if let error = appState.scanError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            Text("Scanning reads your photos on-device. Nothing leaves this phone.")
                .secondaryCaption()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var scanButton: some View {
        Button {
            Task { await appState.runScan() }
        } label: {
            if appState.isScanning {
                ProgressView("Scanning…")
                    .frame(maxWidth: .infinity)
            } else {
                Label("Scan my photos", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
        }
        .primaryActionButton()
        .disabled(appState.isScanning)
        .accessibilityIdentifier("scan-button")
    }

    /// The swipe-mode entry card, above the category cards. Shown
    /// only when at least one month has reviewable cards. The
    /// subtitle names the newest month and its card count (or the
    /// in-progress count when a session is open for that month).
    @ViewBuilder
    private var swipeEntryCard: some View {
        if let newest = appState.swipeMonths.first {
            Button {
                showingSwipeMode = true
            } label: {
                HStack {
                    HomeRowIcon(systemName: AppIcons.resultsStack)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppCopy.swipeToReview)
                            .font(.headline)
                        Text(swipeSubtitle(for: newest))
                            .secondaryCaption()
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .accessibilityIdentifier("home-swipe-card")
            .swipeModeCover(isPresented: $showingSwipeMode)
        }
    }

    private func swipeSubtitle(for month: SwipeMonth) -> String {
        let label = month.title
        let total = appState.swipeCardCount(for: month)
        if let session = appState.swipeSession,
           session.month == month, session.decidedCount > 0 {
            return "Swipe through \(label): \(session.decidedCount) of \(total) reviewed"
        }
        return "Swipe through \(label): \(total) cards to review"
    }

    private func summaryCard(_ result: ScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Could free up")
                        .secondaryCaption()
                    Text(StorageEstimator.approx(result.totalReclaimableBytes))
                        .font(.title.bold())
                        .accessibilityIdentifier("reclaimable-total")
                    Text("estimate: \(result.totalDeletableCount) photos across \(result.groups.count) groups")
                        .secondaryCaption()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(result.totalScanned)")
                        .font(.title3.bold())
                    Text("photos scanned")
                        .secondaryCaption()
                }
            }
            scanButton
        }
        .padding()
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private func categoryCards(_ result: ScanResult) -> some View {
        // Tight spacing on purpose: the swipe entry card above adds
        // one row, and the "How it works" steps below must still clear
        // the floating tab bar at rest in shot 01 (CI run 44450339524:
        // spacing 12 here plus the new card pushed step 3 behind the
        // bar). The rows keep their own height; only the gaps shrink.
        VStack(spacing: 8) {
            ForEach(GroupKind.allCases, id: \.rawValue) { kind in
                NavigationLink {
                    CategoryGroupsView(kind: kind)
                } label: {
                    CategoryCardRow(kind: kind, result: result)
                }
                .accessibilityIdentifier("home-category-\(kind.categoryID)")
            }
            NavigationLink {
                LivePhotosView()
            } label: {
                LivePhotosCardRow(result: result)
            }
            .accessibilityIdentifier("home-category-livephotos")
        }
    }

    private func partialScanNotice(_ result: ScanResult) -> some View {
        Label(
            "Scanned \(result.totalScanned) of \(result.totalLibraryCount) photos with limited photo access. Grant full access in Settings to scan the rest.",
            systemImage: "exclamationmark.triangle"
        )
        .secondaryCaption()
        .padding()
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How it works")
                .font(.headline)
            // One line per step, on purpose: the whole section has to
            // fit above the floating tab bar at rest in shot 01 (a
            // scroll to reveal it ghosts the header under the nav bar).
            // test01 asserts step 3 is hittable, so a future wrap fails
            // loudly in CI instead of silently cutting the shot.
            ForEach(Array([
                "1. Scan on-device. Nothing is uploaded.",
                "2. Review: pick the keeper, the rest are proposed.",
                "3. Delete only when you confirm. Undo for 30 days.",
            ].enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // Identifier for the screenshot lane: test01 asserts
                    // step 3 is hittable above the tab bar.
                    .accessibilityIdentifier("how-it-works-step-\(index + 1)")
            }
            // No footer caption here: the Apple Photos note lives in
            // Settings > About and in the listing. A caption under the
            // steps wrapped to two lines and the second line sat
            // half-hidden behind the floating tab bar in the 01 shot.
        }
    }
}

/// One category card on the Home screen. A separate View (not a
/// closure in `categoryCards`) because the counts need plain Swift
/// `if` statements — assignments inside a @ViewBuilder closure break
/// ForEach overload resolution (the compiler falls back to the Binding
/// overload and fails). Computing the counts as properties here keeps
/// the ForEach closure a pure view.
struct CategoryCardRow: View {
    let kind: GroupKind
    let result: ScanResult

    private var groupCount: Int {
        kind == .largeVideos ? result.largeVideos.count : result.groups(of: kind).count
    }

    private var frees: Int64 {
        if kind == .largeVideos {
            return result.largeVideos.reduce(0) { $0 + $1.fileSize }
        }
        return result.groups(of: kind).reduce(0) { $0 + $1.reclaimableBytes }
    }

    var body: some View {
        HomeRow(
            icon: icon,
            title: kind.sectionTitle,
            subtitle: subtitle,
            frees: frees
        )
    }

    private var icon: String {
        switch kind {
        case .exactDuplicate: return "doc.on.doc"
        case .similar: return "square.stack.3d.up"
        case .blurry: return "eye.slash"
        case .screenshots: return AppIcons.screenshotsTab
        case .largeVideos: return AppIcons.videos
        }
    }

    private var subtitle: String {
        switch kind {
        case .largeVideos:
            return groupCount == 0 ? "No large videos found" : "\(groupCount) large videos"
        default:
            return groupCount == 0 ? "Nothing found" : "\(groupCount) group\(groupCount == 1 ? "" : "s") to review"
        }
    }
}

/// The Live Photos card on the Home screen. A separate row, not a
/// GroupKind: Live Photos are a list to convert, not a deletion group.
struct LivePhotosCardRow: View {
    let result: ScanResult

    private var count: Int {
        result.livePhotos.count
    }

    private var frees: Int64 {
        result.livePhotos.reduce(0) { $0 + LivePhotoConversion.estimate(originalBytes: $1.fileSize).bytesSaved }
    }

    var body: some View {
        HomeRow(
            icon: "livephoto",
            title: AppCopy.livePhotos,
            subtitle: count == 0 ? "No Live Photos found" : "\(count) Live Photos to convert",
            frees: frees
        )
    }
}

/// The shared home row shell: tinted icon, title + subtitle, optional
/// frees label on the right. CategoryCardRow and LivePhotosCardRow keep
/// their own counts and copy; only the layout is shared, so both rows
/// stay identical. No vertical padding here: the rows sit in a spacing-8
/// stack, and the extra 4pt per row (7 rows) pushed "How it works" step 3
/// behind the tab bar once the swipe entry card was added (CI run
/// 44450339524). The rows are still ~40pt tall from their content.
private struct HomeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let frees: Int64

    var body: some View {
        HStack {
            HomeRowIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .secondaryCaption()
            }
            Spacer()
            if frees > 0 {
                Text(StorageEstimator.freesLabel(frees))
                    .font(.subheadline.bold())
            }
        }
        .padding(.vertical, 0)
    }
}

/// The tinted leading icon shared by the three home rows (swipe entry,
/// category, Live Photos): same 28pt width so the row titles align.
private struct HomeRowIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(.tint)
            .frame(width: 28)
    }
}

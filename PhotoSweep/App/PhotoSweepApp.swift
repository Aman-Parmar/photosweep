import SwiftData
import SwiftUI

/// PhotoSweep — Free up iPhone storage, honestly.
/// No account, no analytics, no ads. All scanning happens on-device;
/// no photo ever leaves the phone. Nothing is deleted without the user
/// reviewing it first and confirming — deletion moves items to Recently
/// Deleted, where Photos keeps them for 30 days.
@main
struct PhotoSweepApp: App {
    @StateObject private var store = StoreManager()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
        }
        .modelContainer(for: [ScanRecord.self, CleanupEventRecord.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label(AppCopy.scan, systemImage: AppIcons.scanTab)
                }
            ResultsView()
                .tabItem {
                    Label(AppCopy.results, systemImage: AppIcons.resultsStack)
                }
            ScreenshotsView()
                .tabItem {
                    Label(AppCopy.screenshots, systemImage: AppIcons.screenshotsTab)
                }
            LargeVideosView()
                .tabItem {
                    Label(AppCopy.videos, systemImage: AppIcons.videos)
                }
            SettingsView()
                .tabItem {
                    Label(AppCopy.settings, systemImage: AppIcons.settings)
                }
        }
        .task {
            // Persist confirmed cleanups so Settings can show what
            // was freed this month (and the widget can, later).
            appState.recordCleanup = { event in
                modelContext.insert(CleanupEventRecord(event: event))
                try? modelContext.save()
            }
            // Screenshot mode only: seed one sample scan record so the
            // history list is never empty in the screenshot lane.
            ScreenshotSeeder.seedIfNeeded(modelContext: modelContext)
            await store.loadProducts()
        }
    }
}

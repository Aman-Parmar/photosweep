import SwiftUI

/// Shared copy for the delete-failure banner shown after a failed
/// confirmDelete. One source so the wording stays identical in the
/// group review and swipe flows.
enum AppCopy {
    static let deleteFailed = "Delete failed. Nothing was removed - try again."

    /// Done-state headline for the compress and convert sheets. One source
    /// so the wording stays identical in both flows.
    static func savedLine(bytes: Int64) -> String {
        "Saved ~\(StorageEstimator.formatted(bytes))"
    }

    /// Screenshot-review warning shown on the screenshots bulk-review list
    /// and on swipe-mode screenshot cards. One source so the wording stays
    /// identical in both places.
    static let screenshotWarning = "Check each one: some screenshots are receipts, tickets, or confirmations worth keeping."

    /// Bulk-delete button label for the screenshots list and the large
    /// videos list. One source so the wording stays identical in both
    /// places; the two buttons keep their own actions and accessibility
    /// identifiers.
    static func deleteSelectedLabel(count: Int) -> String {
        "Delete \(count) selected"
    }

    /// Dismiss label for sheet and flow Done buttons (compress, convert,
    /// swipe deck, month picker, month done). One source so the wording
    /// stays identical in all five places; each button keeps its own
    /// action and accessibility identifier.
    static let done = "Done"

    /// Dismiss label for sheet Close buttons (compare sheet, privacy
    /// sheet, paywall). One source so the wording stays identical in
    /// all three places; each button keeps its own action.
    static let close = "Close"

    /// Dismiss label for sheet Cancel buttons (compress, convert, swipe
    /// batch review) and the delete-confirm alert. One source so the
    /// wording stays identical in all four places; each button keeps
    /// its own action and role.
    static let cancel = "Cancel"

    /// Source-item row label in the compress and convert sheets. One
    /// source so the wording stays identical in both flows.
    static let original = "Original"

    /// Retry button label shown in the failed phase of the compress and
    /// convert flows. One source so the wording stays identical in both.
    static let tryAgain = "Try again"

    /// Keeper badge label shown on the kept photo in the group review
    /// grid and on swipe-mode cards. One source so the wording stays
    /// identical in both places; each badge keeps its own padding for
    /// its thumbnail size.
    static let keep = "KEEP"

    /// Delete-confirm message for the bulk-review lists (screenshots,
    /// large videos). One source so the wording stays identical in both
    /// places; the caller supplies the plural item noun.
    static func recentlyDeletedMessage(noun: String) -> String {
        "These \(noun) will move to Recently Deleted in Photos, where you can recover them for 30 days."
    }
}

/// The "Move to Recently Deleted?" confirmation alert, shared by the
/// group review, screenshots bulk review, and large videos views so the
/// title, buttons, and wording cannot drift apart. Callers supply the
/// message (which names the item kind) and the confirm action.
struct DeleteConfirmAlert: ViewModifier {
    @Binding var isPresented: Bool
    var count: Int
    var message: String
    var onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.alert("Move to Recently Deleted?", isPresented: $isPresented) {
            Button(AppCopy.cancel, role: .cancel) {}
            Button("Delete \(count)", role: .destructive, action: onConfirm)
        } message: {
            Text(message)
        }
    }
}

extension View {
    func deleteConfirmAlert(
        isPresented: Binding<Bool>,
        count: Int,
        message: String,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            DeleteConfirmAlert(
                isPresented: isPresented,
                count: count,
                message: message,
                onConfirm: onConfirm
            )
        )
    }
}

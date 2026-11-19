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
            Button("Cancel", role: .cancel) {}
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

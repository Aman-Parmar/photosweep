import SwiftUI

/// Shared copy for the delete-failure banner shown after a failed
/// confirmDelete. One source so the wording stays identical in the
/// group review and swipe flows.
enum AppCopy {
    static let deleteFailed = "Delete failed. Nothing was removed - try again."

    /// Done-state headline for the compress and convert sheets. One source
    /// so the wording stays identical in both flows.
    static func savedLine(bytes: Int64) -> String {
        "Saved \(StorageEstimator.approx(bytes))"
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

    /// Delete-confirm button label for the group review and the swipe
    /// batch review. One source so the wording and pluralisation stay
    /// identical in both flows; the group review appends its frees
    /// suffix at the call site, and each button keeps its own action
    /// and accessibility identifier.
    static func deletePhotosLabel(count: Int) -> String {
        "Delete \(count) photo\(count == 1 ? "" : "s")"
    }

    /// Free-tier budget line shown in the group review and in Settings.
    /// One source so the wording stays identical in both places; the
    /// group review appends its "Pro deletes unlimited." suffix at the
    /// call site, and each line keeps its own styling.
    static func freeDeletesLeft(remaining: Int) -> String {
        "Free: \(remaining) of \(AppState.freeDeleteLimit) deletes left"
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

    /// Keeper badge style shared by the group review grid and the
    /// swipe-mode card: caption2 bold white text on an accent capsule.
    /// One source so the badge cannot drift apart; each badge keeps its
    /// own padding for its thumbnail size.
    func keeperBadge() -> some View {
        font(.caption2.bold())
            .background(Color.accentColor, in: Capsule())
            .foregroundStyle(.white)
    }

    /// Dark-circle overlay icon shared by the delete (trash) and compare
    /// icons on group-review photo tiles: caption white glyph on a
    /// translucent black circle. One source so the tile icons cannot
    /// drift apart; each icon keeps its own symbol, action, and outer
    /// padding for its tile position.
    func thumbnailOverlayIcon() -> some View {
        font(.caption)
            .padding(6)
            .background(Color.black.opacity(0.55), in: Circle())
            .foregroundStyle(.white)
    }

    /// Primary action button style shared by the scan, group-delete,
    /// compare-keep, bulk-delete, compress, convert, and swipe-commit
    /// buttons: prominent bordered style at large control size. One
    /// source so the primary action cannot drift apart; each button
    /// keeps its own label, action, width, disabled state, and
    /// accessibility identifier. The paywall buy buttons and the
    /// swipe-deck Keep/Delete buttons use the prominent style without
    /// the large size by design, and the secondary buttons use the
    /// plain bordered style, so they do not use this helper.
    func primaryActionButton() -> some View {
        buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    /// Delete-failure caption shared by the group review and the swipe
    /// batch review: caption red text on the shared AppCopy.deleteFailed
    /// wording. One source so the banner cannot drift apart; each banner
    /// keeps its own placement and condition.
    func deleteFailedCaption() -> some View {
        font(.caption)
            .foregroundStyle(.red)
    }

    /// Screenshot-warning caption shared by the screenshots bulk-review
    /// list and the swipe-mode screenshot cards: caption secondary text
    /// on the shared AppCopy.screenshotWarning wording. One source so
    /// the warning cannot drift apart; each warning keeps its own
    /// placement.
    func screenshotWarningCaption() -> some View {
        font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Cancellation-action toolbar button shared by the paywall, the
    /// compress and convert sheets, and the Settings privacy sheet: a
    /// Close/Cancel button in the cancellation slot. One source so the
    /// placement cannot drift apart; each caller keeps its own label
    /// (Close vs Cancel) and dismiss action. The swipe review batch
    /// uses a trailing Cancel button by design, so it does not use
    /// this helper.
    func cancellationButton(label: String, action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(label, action: action)
            }
        }
    }
}

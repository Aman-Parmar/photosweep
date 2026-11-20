import Photos
import SwiftUI

/// Loads a real thumbnail for a library asset on demand.
/// In screenshot mode this is never used — views show generated
/// synthetic images instead (see `SampleImageGenerator`).
@MainActor
final class ThumbnailLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let manager = PHCachingImageManager()

    func load(assetID: String, targetSize: CGSize = CGSize(width: 240, height: 240)) {
        guard image == nil else { return }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
        guard let asset = assets.firstObject else { return }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        Self.manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            self?.image = image
        }
    }
}

/// Corner radius shared by the small thumbnails: the 56pt list-row
/// thumbnail below and the 84x56 video-row thumbnail in
/// ScreenshotsAndVideosView. One source so the two stay in sync
/// instead of drifting as separate magic numbers. The results-flow
/// thumbnails use the larger `thumbnailCornerRadius` (10) in
/// ResultsView and stay separate by design.
let smallThumbnailCornerRadius: CGFloat = 8

/// The 56pt square list-row thumbnail used by the group row, the
/// screenshots list, the Live Photos list, and the swipe member
/// strip: one place for the size so the four lists stay identical.
/// The video row (84x56), group-review grid (110pt), compare view,
/// and swipe keeper (300pt) are different sizes by design and stay
/// inline.
struct ListThumbnailView: View {
    let item: PhotoItem
    /// Synthetic hue used only in screenshot mode (derived from the item id).
    let sampleHue: Double

    /// The hue is always derived from the item id at every call site,
    /// so it defaults here instead of being repeated at each one; an
    /// explicit hue can still be passed when a caller needs it.
    init(item: PhotoItem, sampleHue: Double? = nil) {
        self.item = item
        self.sampleHue = sampleHue ?? SampleImageGenerator.hue(for: item.id)
    }

    var body: some View {
        PhotoThumbnailView(item: item, sampleHue: sampleHue)
            .frame(width: 56, height: 56)
            .cornerRadius(smallThumbnailCornerRadius)
    }
}

/// Shows a thumbnail for a `PhotoItem`: a real Photos thumbnail in
/// normal use, a generated synthetic image in screenshot mode.
struct PhotoThumbnailView: View {
    let item: PhotoItem
    /// Synthetic hue used only in screenshot mode (derived from the item id).
    let sampleHue: Double

    /// The hue is always derived from the item id at every call site,
    /// so it defaults here instead of being repeated at each one; an
    /// explicit hue can still be passed when a caller needs it.
    init(item: PhotoItem, sampleHue: Double? = nil) {
        self.item = item
        self.sampleHue = sampleHue ?? SampleImageGenerator.hue(for: item.id)
    }

    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        Group {
            if ScreenshotMode.isEnabled {
                Image(uiImage: SampleImageGenerator.thumbnail(for: item, hue: sampleHue))
                    .resizable()
                    .scaledToFill()
            } else if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.25))
                    .overlay {
                        Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .clipped()
        .task {
            if !ScreenshotMode.isEnabled {
                loader.load(assetID: item.id)
            }
        }
        .accessibilityLabel(item.isVideo ? "Video thumbnail" : "Photo thumbnail")
    }
}

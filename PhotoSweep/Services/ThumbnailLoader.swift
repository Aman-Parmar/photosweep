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

/// Shows a thumbnail for a `PhotoItem`: a real Photos thumbnail in
/// normal use, a generated synthetic image in screenshot mode.
struct PhotoThumbnailView: View {
    let item: PhotoItem
    /// Synthetic hue used only in screenshot mode (derived from the item id).
    let sampleHue: Double

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

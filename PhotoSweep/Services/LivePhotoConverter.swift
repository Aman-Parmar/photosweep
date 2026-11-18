import Foundation
import Photos
import UniformTypeIdentifiers

/// On-device Live Photo to still conversion. No network, no server:
/// the still image data is read from the asset on the phone and saved
/// as a new photo, keeping the original creation date and location so
/// the still keeps its place in the library timeline.
///
/// Only the conversion lives here. Moving the original to Recently
/// Deleted is AppState's job (`convertLivePhoto`), because that is
/// where the user-confirmation and free-tier rules are enforced. This
/// type never deletes anything.
enum LivePhotoConverter {

    enum ConversionError: LocalizedError {
        case noStillData
        case stillSaveFailed(String)

        var errorDescription: String? {
            switch self {
            case .noStillData:
                return "Could not read the still photo from this Live Photo."
            case .stillSaveFailed(let detail):
                return "Could not save the still photo: \(detail)"
            }
        }
    }

    /// The saved still plus its real size. The caller owns nothing on
    /// disk: the temporary file is removed before returning.
    struct ConvertedLivePhoto {
        let stillFileSize: Int64
    }

    /// Extracts the still from `asset` and saves it as a new photo,
    /// preserving the original creation date and location. Reports
    /// progress 0...1 on the main thread. Throws on any failure; a
    /// failed conversion saves nothing and changes nothing.
    static func convert(
        asset: PHAsset,
        progress: @escaping (Double) -> Void
    ) async throws -> ConvertedLivePhoto {
        let options = PHImageRequestOptions()
        options.version = .current
        options.deliveryMode = .highQualityFormat
        // An iCloud-only Live Photo downloads first.
        options.isNetworkAccessAllowed = true
        // For a Live Photo this returns the still image data (the
        // original file bytes, JPEG or HEIC), not the video clip.
        let (data, dataUTI) = await withCheckedContinuation { (continuation: CheckedContinuation<(Data?, String?), Never>) in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, dataUTI, _, _ in
                continuation.resume(returning: (data, dataUTI))
            }
        }
        guard let data, !data.isEmpty else { throw ConversionError.noStillData }
        DispatchQueue.main.async { progress(0.5) }

        // The still data is the original file bytes: write them out
        // untouched, never re-encoded.
        let fileExtension = dataUTI.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg"
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photosweep-livephoto-\(UUID().uuidString).\(fileExtension)")
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let creationDate = asset.creationDate
        let location = asset.location
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: fileURL, options: nil)
                request.creationDate = creationDate
                request.location = location
            }
        } catch {
            throw ConversionError.stillSaveFailed(error.localizedDescription)
        }
        DispatchQueue.main.async { progress(1) }
        return ConvertedLivePhoto(stillFileSize: Int64(data.count))
    }
}

import AVFoundation
import Foundation

/// On-device HEVC video compression. No network, no server: the video
/// is re-encoded on the phone with AVAssetReader / AVAssetWriter.
///
/// The export keeps the original's orientation (the video track's
/// preferred transform is passed through to the writer) and its audio
/// (passed through untouched, not re-encoded). The frame is capped at
/// the preset's max dimension, never upscaled.
///
/// Only the export lives here. Saving the compressed copy to Photos
/// and moving the original to Recently Deleted is AppState's job
/// (`compressVideo`), because that is where the user-confirmation and
/// free-tier rules are enforced. This type never touches the library.
enum VideoCompressor {

    enum CompressionError: LocalizedError {
        case noVideoTrack
        case zeroDuration
        case exportFailed(String)

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "This video has no video track to compress."
            case .zeroDuration:
                return "This video has no duration to compress."
            case .exportFailed(let detail):
                return "Compression failed: \(detail)"
            }
        }
    }

    /// The exported file plus its real size. The caller owns the
    /// file: it lives in the temporary directory and must be saved
    /// or deleted by the caller.
    struct ExportedVideo {
        let fileURL: URL
        let fileSize: Int64
    }

    /// Exports `asset` to a temporary HEVC .mp4 at the preset's
    /// resolution and bitrate, reporting progress 0...1 on the main
    /// thread. Throws on any failure; a failed export leaves no
    /// partial file behind.
    static func export(
        asset: AVAsset,
        preset: CompressionPreset,
        progress: @escaping (Double) -> Void
    ) async throws -> ExportedVideo {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw CompressionError.noVideoTrack
        }
        let duration = asset.duration.seconds
        guard duration > 0 else { throw CompressionError.zeroDuration }
        let target = VideoCompression.targetSize(
            originalWidth: Int(videoTrack.naturalSize.width),
            originalHeight: Int(videoTrack.naturalSize.height),
            preset: preset
        )

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("photosweep-compress-\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        let reader = try AVAssetReader(asset: asset)
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        )
        reader.add(videoOutput)

        let audioTrack = asset.tracks(withMediaType: .audio).first
        var audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            // Nil output settings: compressed samples pass through
            // untouched, so the audio is never re-encoded.
            let output = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(output)
            audioOutput = output
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: target.width,
                AVVideoHeightKey: target.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: preset.nominalBitRateForEncoding,
                    AVVideoExpectedSourceFrameRateKey: 30,
                    AVVideoMaxKeyFrameIntervalKey: 60,
                ],
            ]
        )
        // Keep the original's rotation/flip: the encoded frames stay
        // in stored orientation and the transform rotates them at
        // playback, exactly as the original file does.
        videoInput.transform = videoTrack.preferredTransform
        videoInput.expectsMediaDataInRealTime = false
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audioInput = input
        }

        guard reader.startReading(), writer.startWriting() else {
            try? FileManager.default.removeItem(at: outputURL)
            throw CompressionError.exportFailed(writer.error?.localizedDescription ?? reader.error?.localizedDescription ?? "could not start")
        }
        writer.startSession(atSourceTime: .zero)

        // The classic requestMediaDataWhenReady pumps, bridged to
        // async with a continuation. Video and audio pump
        // independently on one serial queue; the writer finishes only
        // once both tracks are done, so the audio is never cut short.
        // Progress comes from the video sample timestamps.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = DispatchQueue(label: "com.singhsec.photosweep.compress")
            var videoDone = false
            var audioDone = audioOutput == nil
            var finished = false
            func finishOnce(_ result: Result<Void, Error>) {
                guard !finished else { return }
                finished = true
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            func maybeFinish() {
                guard videoDone, audioDone else { return }
                writer.finishWriting {
                    if writer.status == .completed {
                        finishOnce(.success(()))
                    } else {
                        finishOnce(.failure(CompressionError.exportFailed(
                            writer.error?.localizedDescription ?? "unknown export error")))
                    }
                }
            }

            videoInput.requestMediaDataWhenReady(on: queue) {
                while videoInput.isReadyForMoreMediaData {
                    guard let sample = videoOutput.copyNextSampleBuffer() else {
                        videoInput.markAsFinished()
                        videoDone = true
                        maybeFinish()
                        return
                    }
                    let seconds = CMSampleBufferGetPresentationTimeStamp(sample).seconds
                    DispatchQueue.main.async {
                        progress(min(1, max(0, seconds / duration)))
                    }
                    videoInput.append(sample)
                }
            }

            if let audioInput, let audioOutput {
                audioInput.requestMediaDataWhenReady(on: queue) {
                    while audioInput.isReadyForMoreMediaData {
                        guard let audioSample = audioOutput.copyNextSampleBuffer() else {
                            audioInput.markAsFinished()
                            audioDone = true
                            maybeFinish()
                            return
                        }
                        audioInput.append(audioSample)
                    }
                }
            }
        }

        // The reader may have failed mid-stream even if the writer
        // finished; surface that instead of a corrupt file.
        if reader.status == .failed {
            try? FileManager.default.removeItem(at: outputURL)
            throw CompressionError.exportFailed(reader.error?.localizedDescription ?? "could not read the video")
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
              let size = attributes[.size] as? NSNumber else {
            try? FileManager.default.removeItem(at: outputURL)
            throw CompressionError.exportFailed("the compressed file is missing")
        }
        DispatchQueue.main.async { progress(1) }
        return ExportedVideo(fileURL: outputURL, fileSize: size.int64Value)
    }
}

extension CompressionPreset {
    /// The bitrate the encoder is told to aim for. The estimate model
    /// in `VideoCompression` uses the same nominal rate, so the
    /// before/after preview and the real encode agree on the target.
    /// `NSNumber` because AVVideoCompressionPropertiesKey takes objects.
    var nominalBitRateForEncoding: NSNumber {
        NSNumber(value: nominalBitrateBitsPerSecond)
    }
}

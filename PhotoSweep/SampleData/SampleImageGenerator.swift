import UIKit

/// Programmatically generated synthetic thumbnails for screenshot mode
/// and tests. Never a real photo: each image is a flat gradient with a
/// circle, a horizon line, and a "SAMPLE" tag, drawn deterministically
/// from the item's id so the same item always looks the same.
///
/// These exist so the screenshot lane shows real app UI with real
/// images, without ever bundling a real person's photo in the repo.
enum SampleImageGenerator {

    /// A 240x240 synthetic thumbnail for a photo item. `hue` picks the
    /// gradient colours; the caller derives it from the item id.
    static func thumbnail(for item: PhotoItem, hue: Double) -> UIImage {
        let size = CGSize(width: 240, height: 240)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cg = context.cgContext
            // Sky gradient: hue -> hue + 0.12 (wrapped to 0...1).
            let top = UIColor(hue: hue, saturation: 0.55, brightness: 0.85, alpha: 1).cgColor
            let bottomHue = (hue + 0.12).truncatingRemainder(dividingBy: 1.0)
            let bottom = UIColor(hue: bottomHue, saturation: 0.45, brightness: 0.45, alpha: 1).cgColor
            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top, bottom] as CFArray,
                locations: [0, 1]
            ) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            // Sun.
            let sunCenter = CGPoint(x: size.width * 0.7, y: size.height * 0.28)
            cg.setFillColor(UIColor(white: 1, alpha: 0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: sunCenter.x - 28, y: sunCenter.y - 28, width: 56, height: 56))
            // Hills.
            let hillHue = (hue + 0.3).truncatingRemainder(dividingBy: 1.0)
            cg.setFillColor(UIColor(hue: hillHue, saturation: 0.5, brightness: 0.35, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: -60, y: size.height * 0.62, width: size.width + 120, height: 140))
            // Blurry items get a soft overlay, so the blurry group
            // looks blurry in the screenshot instead of identical.
            if item.sharpness <= SimilarityEngine.blurrySharpnessThreshold {
                cg.setFillColor(UIColor(white: 1, alpha: 0.35).cgColor)
                cg.fill(CGRect(origin: .zero, size: size))
            }
            // Video badge.
            if item.isVideo {
                cg.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
                cg.fillEllipse(in: CGRect(x: size.width / 2 - 26, y: size.height / 2 - 26, width: 52, height: 52))
                cg.setFillColor(UIColor.white.cgColor)
                let triangle = CGMutablePath()
                triangle.move(to: CGPoint(x: size.width / 2 - 8, y: size.height / 2 - 14))
                triangle.addLine(to: CGPoint(x: size.width / 2 - 8, y: size.height / 2 + 14))
                triangle.addLine(to: CGPoint(x: size.width / 2 + 14, y: size.height / 2))
                triangle.closeSubpath()
                cg.addPath(triangle)
                cg.fillPath()
            }
            // "SAMPLE" tag, bottom-left, so no one mistakes this for a
            // real photo. Drawn well inside the image, not at the very
            // bottom edge: tiles show the image with scaledToFill, and
            // the wider tiles (video thumbs ~1.35 aspect) crop ~13% off
            // the bottom, which used to slice the tag in half in the
            // group-review shots. A 66pt bottom margin keeps it whole
            // in every tile shape.
            let label = "SAMPLE"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 13),
                .foregroundColor: UIColor.white,
            ]
            label.draw(at: CGPoint(x: 10, y: size.height - 82), withAttributes: attributes)
        }
    }

    /// A stable hue (0...1) derived from an item id.
    static func hue(for id: String) -> Double {
        let hash = id.utf8.reduce(0) { ($0 &* 31) &+ Int($1) }
        return Double(abs(hash) % 360) / 360.0
    }
}

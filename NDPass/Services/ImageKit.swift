import UIKit
import ImageIO

/// Images at the size NDPass needs, never bigger. A 24 MP camera photo is ~100 MB once
/// decoded, and the share sheet only gets ~120 MB in total, so photos are shrunk straight
/// from their file data (ImageIO decodes at the smaller size) and drawn art is made at 1x.
enum ImageKit {
    /// The longest side photos are kept at: plenty to read text and barcodes.
    static let photoPixels: CGFloat = 2400

    /// Decode `data` at most `maxPixel` on its longest side, upright.
    static func downsample(_ data: Data, maxPixel: CGFloat = photoPixels) -> UIImage? {
        let opts = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithData(data as CFData, opts) else { return nil }
        let thumb: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // applies the EXIF orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixel))
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumb as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// An image already in memory (the camera's), upright and at most `maxPixel` on its
    /// longest side.
    static func fit(_ img: UIImage, maxPixel: CGFloat = photoPixels) -> UIImage {
        let w = img.size.width * img.scale, h = img.size.height * img.scale
        let s = min(1, maxPixel / max(w, h, 1))
        if s == 1, img.imageOrientation == .up, img.scale == 1 { return img }
        let size = CGSize(width: (w * s).rounded(), height: (h * s).rounded())
        return renderer(size).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// A renderer that draws at exactly `size` pixels (not the screen's 3x).
    static func renderer(_ size: CGSize) -> UIGraphicsImageRenderer {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f)
    }

    /// Decoded art for the cover, cached so grids and the calendar don't decode it on every
    /// redraw.
    private static let cache: NSCache<NSString, UIImage> = { let c = NSCache<NSString, UIImage>(); c.countLimit = 120; return c }()
    static func art(_ data: Data, id: String) -> UIImage? {
        let key = "\(id)-\(data.count)" as NSString
        if let img = cache.object(forKey: key) { return img }
        guard let img = downsample(data, maxPixel: 1200) else { return nil }
        cache.setObject(img, forKey: key)
        return img
    }
}

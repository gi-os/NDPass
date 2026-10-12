import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// Reads the ticket's real code out of the photo, and draws a code to show at the door.
enum Barcodes {
    static func symbology(_ s: VNBarcodeSymbology) -> Symbology {
        switch s {
        case .qr, .microQR: return .qr
        case .pdf417, .microPDF417: return .pdf417
        case .aztec: return .aztec
        case .dataMatrix: return .dataMatrix
        case .code128: return .code128
        default: return .other
        }
    }

    /// The crop first (less paper, fewer false edges), then the whole photo, then inverted
    /// for a ticket shown on a phone in dark mode.
    static func read(crop: UIImage?, photo: UIImage) -> CodeScan.Found? {
        var found: [CodeScan.Found] = []
        let sources = [crop, photo].compactMap { $0 }
        for src in sources {
            for inverted in [false, true] {
                guard let cg = cgImage(src, inverted: inverted) else { continue }
                let req = VNDetectBarcodesRequest()
                try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
                for obs in req.results ?? [] {
                    guard let text = obs.payloadStringValue else { continue }
                    let f = CodeScan.Found(text: text, format: symbology(obs.symbology))
                    found.append(f)
                    if CodeScan.isConclusive(f) { return CodeScan.best(found) }
                }
            }
        }
        return CodeScan.best(found)
    }

    private static func cgImage(_ img: UIImage, inverted: Bool) -> CGImage? {
        guard let cg = img.cgImage else { return nil }
        guard inverted else { return cg }
        let f = CIFilter.colorInvert(); f.inputImage = CIImage(cgImage: cg)
        guard let out = f.outputImage else { return nil }
        return CIContext().createCGImage(out, from: out.extent)
    }

    /// A crisp code image, at most `fit` pixels on its long side: whole pixels per module,
    /// black on opaque white. Nil for symbologies Core Image cannot draw (Data Matrix).
    /// The Lock Screen asks for ~300 px; a Live Activity drops any image bigger than the
    /// activity itself and shows a grey box instead.
    static func render(_ text: String, as sym: Symbology, fit: CGFloat = 900) -> UIImage? {
        let data = Data(text.utf8)
        var out: CIImage?
        switch sym {
        case .qr: let f = CIFilter.qrCodeGenerator(); f.message = data; f.correctionLevel = "M"; out = f.outputImage
        case .code128:
            guard let ascii = text.data(using: .ascii) else { return render(text, as: .qr, fit: fit) }
            let f = CIFilter.code128BarcodeGenerator(); f.message = ascii; f.quietSpace = 10; out = f.outputImage
        case .pdf417: let f = CIFilter.pdf417BarcodeGenerator(); f.message = data; out = f.outputImage
        case .aztec: let f = CIFilter.aztecCodeGenerator(); f.message = data; out = f.outputImage
        case .dataMatrix, .other: return nil
        }
        // One pixel per module first, then scaled up by whole pixels with no smoothing.
        guard let img = out, let small = CIContext().createCGImage(img, from: img.extent.integral) else { return nil }
        let w = CGFloat(small.width), h = CGFloat(small.height)
        let k = max(1, (fit / max(w, h)).rounded(.down))
        // 1D bars are drawn short; stretch them taller, still inside `fit`.
        let ky = sym == .code128 ? max(k, min(k * 4, (fit * 0.45 / h).rounded(.down))) : k
        let size = CGSize(width: w * k, height: h * ky)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
            let c = ctx.cgContext
            UIColor.white.setFill(); c.fill(CGRect(origin: .zero, size: size))
            c.interpolationQuality = .none
            // Core Graphics draws bottom-up; flip so the code isn't mirrored.
            c.translateBy(x: 0, y: size.height); c.scaleBy(x: 1, y: -1)
            c.draw(small, in: CGRect(origin: .zero, size: size))
        }
    }
}

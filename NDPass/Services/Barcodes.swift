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

    /// A crisp code image. Nil for symbologies Core Image cannot draw (Data Matrix).
    static func render(_ text: String, as sym: Symbology) -> UIImage? {
        let data = Data(text.utf8)
        var out: CIImage?
        switch sym {
        case .qr: let f = CIFilter.qrCodeGenerator(); f.message = data; f.correctionLevel = "M"; out = f.outputImage
        case .code128:
            guard let ascii = text.data(using: .ascii) else { return render(text, as: .qr) }
            let f = CIFilter.code128BarcodeGenerator(); f.message = ascii; f.quietSpace = 10; out = f.outputImage
        case .pdf417: let f = CIFilter.pdf417BarcodeGenerator(); f.message = data; out = f.outputImage
        case .aztec: let f = CIFilter.aztecCodeGenerator(); f.message = data; out = f.outputImage
        case .dataMatrix, .other: return nil
        }
        guard let img = out else { return nil }
        let scale = max(1, (900 / img.extent.width).rounded(.down))
        let big = img.samplingNearest().transformed(by: CGAffineTransform(scaleX: scale, y: scale * (sym == .code128 ? 4 : 1)))
        guard let cg = CIContext().createCGImage(big, from: big.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

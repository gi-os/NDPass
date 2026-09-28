import Foundation

enum Symbology: String, Codable { case qr, code128, pdf417, aztec, dataMatrix, other }

/// The booking reference, and what shape of code it wants to be. From BookingCode.kt.
enum BookingCode {
    static let pdf417From = 40
    static let code128UpTo = 20
    static let minLength = 4
    static let notACode: Set<String> = ["null", "none", "n/a", "na", "-", "--", "unknown"]

    /// Only the ends are trimmed: the string has to come back out of a scanner byte for byte.
    static func normalize(_ raw: String?) -> String? {
        guard let code = raw?.trimmingCharacters(in: .whitespacesAndNewlines), code.count >= minLength else { return nil }
        if notACode.contains(code.lowercased()) { return nil }
        return code
    }

    static func symbology(for code: String) -> Symbology {
        if code.count > pdf417From { return .pdf417 }
        if code.count > code128UpTo { return .qr }
        if code.wholeMatch(of: #/[A-Za-z0-9-]+/#) == nil { return .qr }
        return .code128
    }
}

/// Reading the ticket's own code off the photograph, and which decode to believe. From CodeScan.kt.
enum CodeScan {
    struct Found: Equatable { let text: String; let format: Symbology }

    static let twoD: Set<Symbology> = [.qr, .pdf417, .aztec, .dataMatrix]
    /// A photo of paper is full of parallel edges; short 1D reads are usually perforations.
    static let min1DLength = 6

    static func isCredible(_ f: Found) -> Bool {
        let t = f.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return false }
        return twoD.contains(f.format) || t.count >= min1DLength
    }

    static func isConclusive(_ f: Found) -> Bool { isCredible(f) && twoD.contains(f.format) }

    /// Prefer 2D (it survives being redrawn), then the longer payload.
    static func best(_ found: [Found]) -> Found? {
        var seen = Set<String>()
        let unique = found.filter(isCredible).filter { seen.insert($0.text).inserted }
        return unique.max { a, b in
            let a2 = twoD.contains(a.format) ? 1 : 0, b2 = twoD.contains(b.format) ? 1 : 0
            return a2 != b2 ? a2 < b2 : a.text.count < b.text.count
        }
    }
}

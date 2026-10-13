import Foundation

/// Routes as NDPass shows them: "NYP → BOS", "New York Penn → Boston South".
enum Transit {
    /// Station and airport codes stay in capitals; names get Title Case when read in all caps.
    static func place(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // A code: printed in capitals ("NYP", "JFK"), or read back in lowercase ("nyp").
        // A name written normally ("Rome", "Bath") stays a name.
        if (2...4).contains(t.count), t.allSatisfy(\.isLetter), t == t.uppercased() || t == t.lowercased() { return t.uppercased() }
        return PassTimes.display(t)
    }

    /// "New York" + "Boston" → "New York → Boston". Nil when neither end is known.
    static func route(_ from: String, _ to: String) -> String? {
        let a = place(from), b = place(to)
        switch (a.isEmpty, b.isEmpty) {
        case (true, true): return nil
        case (false, true): return a
        case (true, false): return "To \(b)"
        default: return "\(a) → \(b)"
        }
    }

    /// "New York → Boston", "NYP - BOS", "Newark to Chicago" → the two ends.
    static func split(_ title: String) -> (String, String)? {
        guard let r = title.firstMatch(of: #/\s*(?:→|->|–|—|\s-\s|\sto\s)\s*/#) else { return nil }
        let a = String(title[..<r.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        let b = String(title[r.range.upperBound...]).trimmingCharacters(in: .whitespaces)
        return a.isEmpty || b.isEmpty ? nil : (a, b)
    }
}

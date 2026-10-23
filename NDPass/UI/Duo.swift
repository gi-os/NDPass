import SwiftUI
import Observation

/// How the window sits on the iPhone Duo's inner display (7.6", about 626 × 890 points, folding
/// in half across its long side). Open like a book, the fold runs top to bottom down the middle;
/// turned upright and half folded like a laptop, it runs across. The outer display, Split View
/// and every other iPhone (440 points across at most, even in landscape) get the phone layout.
enum Fold: Equatable {
    case phone, open, upright

    /// Narrowest side of a window that can only be the inner display. Below the Duo's 626 so a
    /// Display Zoom setting still counts, above any other iPhone.
    static let minSide: CGFloat = 500

    static func of(_ window: CGSize) -> Fold {
        guard min(window.width, window.height) >= minSide else { return .phone }
        return window.width > window.height ? .open : .upright
    }
}

/// The window's size, kept by RootView so any screen (sheets and covers too) knows the fold.
@Observable
final class Duo {
    static let shared = Duo()
    /// Space left clear over the hinge.
    static let gap: CGFloat = 24

    var window: CGSize = UIScreen.main.bounds.size
    var fold: Fold { Fold.of(window) }

    func update(_ size: CGSize) { if size != window { window = size } }

    /// The window itself. What SwiftUI measures leaves out the iPhone Duo's side tab bar, which
    /// put the cut 39 points short of the hinge.
    static func windowSize(or measured: CGSize) -> CGSize {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        return (windows.first(where: \.isKeyWindow) ?? windows.first)?.bounds.size ?? measured
    }
}

/// Two panes that meet at the fold, with nothing on the hinge: side by side when the inner
/// display is open, one above the other when it's upright. On a phone the cut is the middle of
/// the view. `axis` forces a direction; by default it follows the fold.
struct HingeSplit<First: View, Second: View>: View {
    var axis: Axis?
    var gap: CGFloat = Duo.gap
    /// Clear: the gap is the page itself, with nothing drawn on the hinge.
    var seam: Color = .clear
    @ViewBuilder var first: First
    @ViewBuilder var second: Second

    var body: some View {
        let duo = Duo.shared
        GeometryReader { geo in
            let f = geo.frame(in: .global)
            let ax = axis ?? (duo.fold == .upright ? .vertical : .horizontal)
            let length = ax == .horizontal ? f.width : f.height
            // The hinge is the middle of the window, wherever this view sits in it.
            let hinge = duo.fold == .phone ? length / 2
                : (ax == .horizontal ? duo.window.width / 2 - f.minX : duo.window.height / 2 - f.minY)
            let cut = min(max(hinge, length * 0.3), length * 0.7)
            let a = max(0, cut - gap / 2), b = max(0, length - cut - gap / 2)
            if ax == .horizontal {
                HStack(spacing: 0) {
                    first.frame(width: a)
                    seam.frame(width: gap)
                    second.frame(width: b)
                }
            } else {
                VStack(spacing: 0) {
                    first.frame(height: a)
                    seam.frame(height: gap)
                    second.frame(height: b)
                }
            }
        }
    }
}

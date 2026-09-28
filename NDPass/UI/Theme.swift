import SwiftUI

enum Theme {
    static let bg = Color(red: 8 / 255, green: 8 / 255, blue: 16 / 255)
    static let cream = Color(red: 0.91, green: 0.84, blue: 0.72)
    static let orange = Color(red: 0.91, green: 0.40, blue: 0.11)
    static let dim = Color.white.opacity(0.55)
}

/// A glass card, NDPass's panel from the Expo version.
struct Glass: ViewModifier {
    var radius: CGFloat = 18
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.white.opacity(0.08)))
    }
}

extension View { func glass(_ r: CGFloat = 18) -> some View { modifier(Glass(radius: r)) } }

/// Poster, event art, the cropped stub, or the photo — whichever the ticket has.
struct PassArt: View {
    let pass: Pass
    var body: some View {
        Group {
            if let url = pass.posterURL {
                AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { fallback }
            } else { fallback }
        }
        .clipped()
    }

    @ViewBuilder private var fallback: some View {
        if let d = pass.art ?? pass.crop ?? pass.photo, let img = UIImage(data: d) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack { Theme.cream.opacity(0.15); Image(systemName: "ticket").font(.title).foregroundStyle(Theme.cream) }
        }
    }
}

import SwiftUI

/// The stub photo, pinch to zoom: the only way to read the small print.
struct PhotoViewer: View {
    let data: Data?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let data, let img = UIImage(data: data) { ZoomView(image: img).ignoresSafeArea() }
            Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).padding(12).glass(22) }.padding()
        }
    }
}

struct ZoomView: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> UIScrollView {
        let s = UIScrollView()
        s.minimumZoomScale = 1; s.maximumZoomScale = 8; s.delegate = context.coordinator
        s.showsVerticalScrollIndicator = false; s.showsHorizontalScrollIndicator = false
        let iv = UIImageView(image: image); iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        s.addSubview(iv)
        NSLayoutConstraint.activate([
            iv.widthAnchor.constraint(equalTo: s.frameLayoutGuide.widthAnchor),
            iv.heightAnchor.constraint(equalTo: s.frameLayoutGuide.heightAnchor),
            iv.leadingAnchor.constraint(equalTo: s.contentLayoutGuide.leadingAnchor),
            iv.trailingAnchor.constraint(equalTo: s.contentLayoutGuide.trailingAnchor),
            iv.topAnchor.constraint(equalTo: s.contentLayoutGuide.topAnchor),
            iv.bottomAnchor.constraint(equalTo: s.contentLayoutGuide.bottomAnchor)
        ])
        context.coordinator.view = iv
        return s
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    func makeCoordinator() -> Coord { Coord() }
    final class Coord: NSObject, UIScrollViewDelegate {
        weak var view: UIView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { view }
    }
}

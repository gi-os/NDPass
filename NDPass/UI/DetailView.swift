import SwiftUI
import SwiftData

/// One showing, and every ticket you have for it.
struct DetailView: View {
    let group: UUID
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var importer: Importer
    @Query private var passes: [Pass]
    @State private var editing: Pass?
    @State private var codeFor: Pass?
    @State private var photoFor: Pass?
    @State private var picking = false
    @State private var merging = false
    @State private var confirmDelete = false

    init(group: UUID) {
        self.group = group
        _passes = Query(filter: #Predicate<Pass> { $0.group == group }, sort: \Pass.seat)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let p = passes.first {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header(p)
                        facts(p)
                        ForEach(passes) { ticket($0) }
                        actions(p)
                    }
                    .padding(.bottom, 40)
                }
            } else {
                Text("This ticket is gone.").foregroundStyle(Theme.dim)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { EditView(pass: $0) }
        .fullScreenCover(item: $codeFor) { CodeFullScreen(pass: $0) }
        .fullScreenCover(item: $photoFor) { p in PhotoViewer(data: p.photo) }
        .sheet(isPresented: $picking) { if let p = passes.first { MoviePicker(passes: passes, query: p.title).environmentObject(importer) } }
        .sheet(isPresented: $merging) { MergePicker(into: passes) }
        .confirmationDialog("Delete \(passes.count == 1 ? "this ticket" : "these \(passes.count) tickets")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for p in passes { Reminders.cancel(p.id); ctx.delete(p) }
                try? ctx.save()
            }
        }
    }

    private func header(_ p: Pass) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let u = p.backdropURL {
                    AsyncImage(url: u) { $0.resizable().scaledToFill() } placeholder: { PassArt(pass: p) }
                } else { PassArt(pass: p) }
            }
            .frame(height: 260).frame(maxWidth: .infinity).clipped()
            LinearGradient(colors: [.clear, Theme.bg], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                Text(p.kind.rawValue.uppercased()).font(.caption.bold()).tracking(1.2).foregroundStyle(Theme.cream)
                Text(p.title).font(.system(size: 30, weight: .heavy)).lineLimit(3)
            }
            .padding(20)
        }
    }

    private func facts(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            row("calendar", PassTimes.humanDate(p.date) ?? "No date")
            if !p.time.isEmpty {
                let ends = p.runtime.flatMap { r in p.start.map { $0.addingTimeInterval(Double(r) * 60) } }
                row("clock", p.time + (ends.map { " – " + $0.formatted(date: .omitted, time: .shortened) } ?? ""))
            }
            if !p.venue.isEmpty {
                Button { openMaps(p.venue) } label: { row("mappin.and.ellipse", p.venue + "  ›") }.buttonStyle(.plain)
            }
            if let s = p.sourceURL, let u = URL(string: s) {
                Link(destination: u) { row("safari", "Open the page  ›") }
            }
            if let o = p.overview { Text(o).font(.subheadline).foregroundStyle(Theme.dim).padding(.top, 4) }
        }
        .padding(16).glass().padding(.horizontal, 16)
    }

    private func row(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) { Image(systemName: icon).frame(width: 20).foregroundStyle(Theme.cream); Text(text) }
    }

    private func ticket(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("SEAT").font(.caption2).foregroundStyle(Theme.dim)
                    Text(p.seat.isEmpty ? "—" : p.seat).font(.title3.bold())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("PRICE").font(.caption2).foregroundStyle(Theme.dim)
                    Text(p.price.isEmpty ? "—" : p.price).font(.title3.bold())
                }
            }
            CodeTile(pass: p).onTapGesture { codeFor = p }
            if p.photo != nil {
                Button { photoFor = p } label: {
                    Label("The stub", systemImage: "photo").frame(maxWidth: .infinity).padding(10)
                }
                .buttonStyle(.plain).glass(12)
            }
            HStack {
                Button("Edit") { editing = p }
                Spacer()
                if p.confidence > 0 { Text("Read with \(Int(p.confidence * 100))% confidence").font(.caption2).foregroundStyle(Theme.dim) }
            }
            .font(.subheadline)
        }
        .padding(16).glass().padding(.horizontal, 16)
    }

    private func actions(_ p: Pass) -> some View {
        VStack(spacing: 10) {
            if p.kind == .movie { wide("Wrong poster? Pick the film", "film") { picking = true } }
            wide("Merge with another ticket", "rectangle.stack.badge.plus") { merging = true }
            wide("Delete", "trash", role: .destructive) { confirmDelete = true }
        }
        .padding(.horizontal, 16)
    }

    private func wide(_ t: String, _ icon: String, role: ButtonRole? = nil, _ a: @escaping () -> Void) -> some View {
        Button(role: role, action: a) { Label(t, systemImage: icon).frame(maxWidth: .infinity).padding(12) }
            .buttonStyle(.plain).foregroundStyle(role == .destructive ? .red : .white).glass(14)
    }

    private func openMaps(_ venue: String) {
        var c = URLComponents(string: "maps://")!
        c.queryItems = [URLQueryItem(name: "q", value: venue)]
        if let u = c.url { UIApplication.shared.open(u) }
    }
}

/// The code at the foot of a ticket: the real one read off the photo when there is one,
/// otherwise one drawn from the booking reference and labelled as such.
struct CodeTile: View {
    let pass: Pass
    var body: some View {
        if let found = CodeFullScreen.code(for: pass) {
            let img = found.0, real = found.1
            VStack(spacing: 6) {
                Image(uiImage: img).interpolation(.none).resizable().scaledToFit().frame(maxHeight: 120)
                    .padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10))
                Text(real ? "From your ticket · tap to show at the door" : "Generated from \(pass.bookingCode) · scans only if the venue used this reference")
                    .font(.caption2).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
            }
        } else {
            Text("No code on this ticket. Add the booking reference in Edit.").font(.caption).foregroundStyle(Theme.dim)
        }
    }
}

struct CodeFullScreen: View {
    let pass: Pass
    @Environment(\.dismiss) private var dismiss
    @State private var saved: CGFloat = 0.5

    static func code(for p: Pass) -> (UIImage, Bool)? {
        if let s = p.scannedCode, let f = p.scannedFormat, let img = Barcodes.render(s, as: f) { return (img, true) }
        if let c = BookingCode.normalize(p.bookingCode), let img = Barcodes.render(c, as: BookingCode.symbology(for: c)) { return (img, false) }
        return nil
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 20) {
                Text(pass.title).font(.title2.bold()).foregroundStyle(.black)
                if !pass.seat.isEmpty { Text("Seat \(pass.seat)").foregroundStyle(.black.opacity(0.6)) }
                if let found = Self.code(for: pass) {
                    Image(uiImage: found.0).interpolation(.none).resizable().scaledToFit().padding(24)
                }
                Text("Tap to close").font(.caption).foregroundStyle(.black.opacity(0.4))
            }
        }
        .onTapGesture { dismiss() }
        .onAppear { saved = UIScreen.main.brightness; UIScreen.main.brightness = 1 }
        .onDisappear { UIScreen.main.brightness = saved }
        .statusBarHidden()
    }
}

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

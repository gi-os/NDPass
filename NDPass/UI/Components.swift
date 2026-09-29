import SwiftUI
import SwiftData
import PhotosUI

/// Groups of tickets for the same showing, upcoming first by showtime or archive newest first.
enum Showings {
    static func groups(_ passes: [Pass], archived: Bool?) -> [[Pass]] {
        let filtered = archived.map { a in passes.filter { $0.isArchived == a } } ?? passes
        let g = Dictionary(grouping: filtered, by: \.group).values.map { $0.sorted { $0.seat < $1.seat } }
        let upcoming = archived == false
        return g.sorted { a, b in upcoming ? a[0].sortDate < b[0].sortDate : a[0].sortDate > b[0].sortDate }
    }

    static func seats(_ g: [Pass]) -> String { g.map(\.seat).filter { !$0.isEmpty }.joined(separator: " ") }
}

/// The + button: photograph a stub or pick a screenshot, with the reading log while it works.
struct ScanMenu<Label: View>: View {
    var onAdded: (Pass) -> Void = { _ in }
    @ViewBuilder var label: () -> Label
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var importer: Importer
    @State private var items: [PhotosPickerItem] = []
    @State private var photos = false
    @State private var camera = false
    @State private var log = false
    @State private var consent = false
    @State private var next: (() -> Void)?

    var body: some View {
        Menu {
            Button { ask { camera = true } } label: { SwiftUI.Label("Photograph a stub", systemImage: "camera") }
            Button { ask { photos = true } } label: { SwiftUI.Label("Pick a photo or screenshot", systemImage: "photo") }
        } label: { label() }
        // Pick as many as you like; each is read and filed in turn.
        .photosPicker(isPresented: $photos, selection: $items, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images)
        .onChange(of: items) { _, picked in
            guard !picked.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for it in picked {
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { images.append(img) }
                }
                items = []
                await runAll(images)
            }
        }
        .fullScreenCover(isPresented: $camera) {
            CameraPicker { img in camera = false; if let img { Task { await run(img) } } }.ignoresSafeArea()
        }
        .sheet(isPresented: $consent) {
            AIConsentSheet { ok in
                AIConsent.granted = ok
                consent = false
                let n = next; next = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { n?() }
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $log) { ScanLog().environmentObject(importer).presentationDetents([.medium]).presentationBackground(Theme.bg) }
    }

    private func ask(_ then: @escaping () -> Void) {
        // Only Claude sends anything off the phone, so only Claude needs asking.
        if ReaderChoice.current == .onDevice || AIConsent.asked { then() } else { next = then; consent = true }
    }

    private func runAll(_ images: [UIImage]) async {
        guard images.count > 1 else { if let img = images.first { await run(img) }; return }
        log = true
        var last: Pass?
        var added = 0
        for (i, img) in images.enumerated() {
            if let p = await importer.add(img, into: ctx) { last = p; added += 1 }
            _ = i
        }
        if let last { onAdded(last) }
        importer.note("Added \(added) of \(images.count) tickets.")
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        if added == images.count { log = false }
    }

    private func run(_ img: UIImage) async {
        log = true
        if let p = await importer.add(img, into: ctx) {
            onAdded(p)
            if importer.lastError == nil {
                try? await Task.sleep(nanoseconds: 900_000_000)
                log = false
            }
        }
    }
}

struct ScanLog: View {
    @EnvironmentObject private var importer: Importer
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(importer.busy ? "Reading your ticket" : importer.lastError == nil ? "Done" : "Stopped").font(Theme.serif(30))
                Spacer()
                if importer.busy { ProgressView().tint(Theme.accent) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(importer.log.enumerated()), id: \.offset) { _, line in
                        Text("› " + line).font(Theme.mono(13)).foregroundStyle(Theme.amber)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let e = importer.lastError { Text(e).font(Theme.sans(14)).foregroundStyle(Theme.accent) }
        }
        .padding(24)
        .foregroundStyle(Theme.ink)
        .background(Theme.bg)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let done: (UIImage?) -> Void
    func makeCoordinator() -> Coord { Coord(done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    final class Coord: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(_ d: @escaping (UIImage?) -> Void) { done = d }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}

/// A stub in a grid or a row: the art cut to a ticket, title and date under it.
struct StubThumb: View {
    let passes: [Pass]
    var height: CGFloat = 150
    var body: some View {
        let p = passes[0]
        VStack(alignment: .leading, spacing: 6) {
            TicketArt(pass: p, logoHeight: height * 0.3)
                .frame(height: height)
                .clipShape(StubShape(corner: 16, notch: 8, at: 0.62))
                .overlay(alignment: .topTrailing) {
                    if passes.count > 1 {
                        Text("×\(passes.count)").font(Theme.mono(12, .medium)).padding(.horizontal, 8).padding(.vertical, 4)
                            .glass(in: Capsule()).padding(8)
                    }
                }
            Text(p.title).font(Theme.sans(14, .medium)).foregroundStyle(Theme.ink).lineLimit(1)
            Text(meta(p)).font(Theme.mono(11)).foregroundStyle(Theme.muted).lineLimit(1)
        }
    }

    private func meta(_ p: Pass) -> String {
        let d = PassTimes.day(p.date).map { $0.formatted(.dateTime.month(.abbreviated).day()).uppercased() } ?? "NO DATE"
        return p.venue.isEmpty ? d : "\(d) · \(p.venue.uppercased())"
    }
}

/// A showing as a row, for the Duo list, the calendar and merging.
struct TicketCard: View {
    let passes: [Pass]
    var selected = false
    var body: some View {
        let p = passes[0]
        HStack(spacing: 16) {
            CoverArt(pass: p).frame(width: 64, height: 84).clipShape(StubShape(corner: 12, notch: 7, at: 0.62))
            VStack(alignment: .leading, spacing: 3) {
                Text(Countdown.eyebrow(for: p)).font(Theme.mono(11)).tracking(1.1).foregroundStyle(Theme.amber)
                Text(p.title).font(Theme.serif(25)).foregroundStyle(Theme.ink).lineLimit(2)
                if !p.venue.isEmpty { Text(p.venue).font(Theme.sans(14)).foregroundStyle(Theme.muted).lineLimit(1) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if !p.time.isEmpty { Text(p.time).font(Theme.mono(14)).foregroundStyle(Theme.ink) }
                if passes.count > 1 { Text("×\(passes.count)").font(Theme.mono(12)).foregroundStyle(Theme.muted) }
            }
        }
        .padding(12)
        .background {
            if selected { Color.clear.glass(22) } else { Color.clear }
        }
        .contentShape(Rectangle())
    }
}

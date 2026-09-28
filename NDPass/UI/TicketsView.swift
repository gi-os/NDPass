import SwiftUI
import SwiftData
import PhotosUI

/// The collection: upcoming by showtime, the archive newest first. A list and a detail side
/// by side on a wide screen (the iPhone Duo's inner display), a stack on a phone.
struct TicketsView: View {
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var importer: Importer
    @Query(sort: \Pass.createdAt) private var passes: [Pass]
    @State private var archive = false
    @State private var selection: UUID?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showScan = false

    private var groups: [[Pass]] {
        let filtered = passes.filter { $0.isArchived == archive }
        let g = Dictionary(grouping: filtered, by: \.group).values.map { $0.sorted { $0.seat < $1.seat } }
        return g.sorted { a, b in archive ? a[0].sortDate > b[0].sortDate : a[0].sortDate < b[0].sortDate }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Picker("", selection: $archive) {
                    Text("Upcoming").tag(false)
                    Text("Archive").tag(true)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                if groups.isEmpty {
                    empty.listRowBackground(Color.clear)
                }
                ForEach(groups, id: \.first!.group) { g in
                    TicketCard(passes: g)
                        .tag(g[0].group)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("NDPass")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button { showCamera = true } label: { Label("Photograph a stub", systemImage: "camera") }
                        Button { showPhotos = true } label: { Label("Pick a photo or screenshot", systemImage: "photo") }
                    } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
            }
        } detail: {
            if let selection {
                DetailView(group: selection)
            } else {
                ZStack { Theme.bg.ignoresSafeArea(); Text("Pick a ticket").foregroundStyle(Theme.dim) }
            }
        }
        .photosPicker(isPresented: $showPhotos, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await run(img) }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { img in showCamera = false; if let img { Task { await run(img) } } }.ignoresSafeArea()
        }
        .sheet(isPresented: $showScan) { ScanLog().environmentObject(importer).presentationDetents([.medium]) }
    }

    private func run(_ img: UIImage) async {
        showScan = true
        if let p = await importer.add(img, into: ctx) {
            archive = p.isArchived
            selection = p.group
            if importer.lastError == nil {
                try? await Task.sleep(nanoseconds: 900_000_000)
                showScan = false
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "ticket").font(.system(size: 44)).foregroundStyle(Theme.cream)
            Text(archive ? "No past showings yet." : "No tickets yet.").font(.headline)
            Text("Tap + and photograph a stub. Claude reads the title, theater, date, time, seat and price.")
                .font(.subheadline).foregroundStyle(Theme.dim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct TicketCard: View {
    let passes: [Pass]
    var body: some View {
        let p = passes[0]
        HStack(spacing: 14) {
            PassArt(pass: p).frame(width: 64, height: 92).clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(p.title).font(.headline).lineLimit(2)
                Text([PassTimes.humanDate(p.date), p.time.isEmpty ? nil : p.time].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(Theme.cream)
                if !p.venue.isEmpty { Text(p.venue).font(.caption).foregroundStyle(Theme.dim).lineLimit(1) }
                if !p.seat.isEmpty { Text("Seat \(passes.map(\.seat).filter { !$0.isEmpty }.joined(separator: ", "))").font(.caption2).foregroundStyle(Theme.dim) }
            }
            Spacer(minLength: 0)
            if passes.count > 1 {
                Text("×\(passes.count)").font(.caption.bold()).padding(6).background(Theme.cream.opacity(0.2), in: Capsule())
            }
        }
        .padding(12)
        .glass()
    }
}

struct ScanLog: View {
    @EnvironmentObject private var importer: Importer
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(importer.busy ? "Reading…" : importer.lastError == nil ? "Done" : "Stopped").font(.headline)
                Spacer()
                if importer.busy { ProgressView() }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(importer.log.enumerated()), id: \.offset) { _, line in
                        Text("› " + line).font(.system(.footnote, design: .monospaced)).foregroundStyle(Theme.cream)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let e = importer.lastError { Text(e).font(.footnote).foregroundStyle(.orange) }
        }
        .padding(20)
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

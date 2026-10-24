import SwiftUI
import SwiftData

/// One showing: the film's art filling the top, the title on it, and a glass stub holding
/// the details, the ticket's code and the button for the door.
struct DetailView: View {
    let group: UUID
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var importer: Importer
    @Query private var queried: [Pass]
    /// The showing's tickets, seats in printed order (F9 before F10).
    private var passes: [Pass] { Showings.sortSeats(queried) }
    @State private var removing: Pass?
    @State private var editing: Pass?
    @State private var photoFor: Pass?
    @State private var door = false
    @State private var countdown = false
    @State private var picking = false
    @State private var pickingTeams = false
    @State private var pickingArtist = false
    @State private var merging = false
    @State private var confirmDelete = false
    /// The art is drawn behind the whole window (the open iPhone Duo), not here.
    let artBehind: Bool

    init(group: UUID, artBehind: Bool = false) {
        self.group = group
        self.artBehind = artBehind
        _queried = Query(filter: #Predicate<Pass> { $0.group == group })
    }

    var body: some View {
        // No full-screen layer beside the content: one that ignores the safe area can stretch its
        // stack to the whole window, and the side bar's inset is measured from the stack's frame.
        // The page color is the navigation container's background instead.
        Group {
            if let p = passes.first {
                // The art runs under the status bar and, on the iPhone Duo, under the side tab
                // bar, and fills the pane top to bottom there; the text keeps clear of the bar.
                EdgeToEdge(edges: [.top, .horizontal]) { side, frame in
                    let art = Duo.shared.fold == .phone ? 500 : max(500, frame.height)
                    ScrollView {
                        ZStack(alignment: .top) {
                            if artBehind {
                                Color.clear.frame(height: art)
                            } else {
                                CoverArt(pass: p, preferBackdrop: p.backdropPath != nil).frame(height: art).frame(maxWidth: .infinity)
                                LinearGradient(stops: [.init(color: Theme.bg.opacity(0.4), location: 0), .init(color: .clear, location: 0.22),
                                                       .init(color: Theme.bg.opacity(0.9), location: 0.8), .init(color: Theme.bg, location: 1)],
                                               startPoint: .top, endPoint: .bottom).frame(height: art)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                Spacer().frame(height: 270)
                                titleBlock(p).padding(.horizontal, 22)
                                panel(p).padding(.horizontal, 16).padding(.top, 18)
                                extras(p).padding(.horizontal, 16).padding(.top, 14)
                            }
                            .padding(.bottom, 60)
                            .padding(.leading, side.leading).padding(.trailing, side.trailing)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                Text("This ticket is gone.").font(Theme.serif(28)).foregroundStyle(Theme.muted)
            }
        }
        // Behind the whole window on the open iPhone Duo, the art shows through the stack.
        .containerBackground(artBehind ? Color.clear : Theme.bg, for: .navigation)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let p = passes.first { Button { editing = p } label: { Label("Edit", systemImage: "pencil") } }
                    switch passes.first?.kind {
                    case .movie: Button { picking = true } label: { Label("Pick the film", systemImage: "film") }
                    case .sports: Button { pickingTeams = true } label: { Label("Pick the teams", systemImage: "sportscourt") }
                    case .concert: Button { pickingArtist = true } label: { Label("Pick the artist", systemImage: "music.mic") }
                    default: EmptyView()
                    }
                    Button { merging = true } label: { Label("Merge with another ticket", systemImage: "rectangle.stack.badge.plus") }
                    if passes.count > 1 {
                        Menu {
                            ForEach(Array(passes.enumerated()), id: \.element.id) { i, t in
                                Button(role: .destructive) { removing = t } label: { Text(t.seat.isEmpty ? "Ticket \(i + 1)" : t.seat) }
                            }
                        } label: { Label("Remove one ticket", systemImage: "minus.circle") }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $editing) { p in EditView(passes: passes, start: passes.firstIndex(where: { $0.id == p.id }) ?? 0).environmentObject(importer) }
        .fullScreenCover(item: $photoFor) { p in PhotoViewer(data: p.photo) }
        .fullScreenCover(isPresented: $door) { DoorView(passes: passes) }
        .fullScreenCover(isPresented: $countdown) { CountdownView(passes: passes) }
        .sheet(isPresented: $picking) { if let p = passes.first { MoviePicker(passes: passes, query: p.title).environmentObject(importer) } }
        .sheet(isPresented: $pickingTeams) { TeamPicker(passes: passes) }
        .sheet(isPresented: $pickingArtist) { if let p = passes.first { ArtistPicker(passes: passes, query: p.title) } }
        .sheet(isPresented: $merging) { MergePicker(into: passes) }
        .confirmationDialog("Delete \(passes.count == 1 ? "this ticket" : "these \(passes.count) tickets")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for p in passes { ctx.delete(p) }
                try? ctx.save()
                dismiss()
            }
        }
        .confirmationDialog("Remove \(removing.map { $0.seat.isEmpty ? "this ticket" : "seat \($0.seat)" } ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let r = removing { ctx.delete(r); try? ctx.save() }
                removing = nil
            }
        }
    }

    private func titleBlock(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kindLine(p)).font(Theme.mono(12)).tracking(1.6).foregroundStyle(Theme.amber)
            if p.logoURL != nil {
                TitleMark(pass: p, maxHeight: 110, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(p.title).font(Theme.serif(52)).foregroundStyle(Theme.ink).lineLimit(3).minimumScaleFactor(0.55)
            }
        }
    }

    private func kindLine(_ p: Pass) -> String {
        var s = p.kindLine
        if let r = p.runtime, p.kind == .movie { s += " · \(r / 60)H \(r % 60)M" }
        return s
    }

    private func panel(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 30)) { c in
                if let s = Countdown.short(to: p.start, now: c.date), !p.isArchived {
                    Text("\(p.kind == .transit ? "DEPARTS" : "STARTS") \(s)").font(Theme.mono(12)).tracking(1.4).foregroundStyle(Theme.amber)
                }
            }
            if p.kind == .transit { tripGrid(p) } else {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
                    GridRow {
                        FieldLabel(title: "Date", value: p.dateLabel)
                        FieldLabel(title: "Time", value: timeRange(p), mono: true)
                    }
                    GridRow {
                        Button { if !p.venue.isEmpty { Maps.open(p.venue) } } label: {
                            FieldLabel(title: "Venue", value: p.venue.isEmpty ? "" : p.venue + "  ›")
                        }
                        .buttonStyle(.plain)
                        FieldLabel(title: passes.count > 1 ? "Seats" : "Seat", value: seatsLine, mono: true)
                    }
                }
            }
            Perforation().padding(.horizontal, -8).padding(.vertical, 2)
            CodeTile(passes: passes)
            if let seller = p.seller, seller.rotatingCode, !passes.contains(where: { $0.scannedCode != nil }) {
                // The code rotates: only the seller's app can get you in.
                Button { Seller.open(p) } label: {
                    Label("Open in \(seller.name)", systemImage: "arrow.up.forward.app").font(Theme.sans(16, .semibold)).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52).background(Theme.accent, in: Capsule())
                }
                Text("\(seller.name) tickets use a code that changes every few seconds, so they only scan from the \(seller.name) app.")
                    .font(Theme.sans(12)).foregroundStyle(Theme.muted)
            } else {
                Button { door = true } label: {
                    Label(p.kind == .transit ? "Show to board" : "Show at the door", systemImage: "sun.max").font(Theme.sans(16, .semibold)).foregroundStyle(Theme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52).background(Theme.accent, in: Capsule())
                }
                .disabled(DoorView.code(for: passes.first) == nil && passes.allSatisfy { $0.photo == nil })
                if let seller = p.seller {
                    Button { Seller.open(p) } label: {
                        Label("Open in \(seller.name)", systemImage: "arrow.up.forward.app").font(Theme.sans(15, .medium)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44).glass(in: Capsule(), interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 22)
        .glass(in: StubShape(corner: 28, notch: 14, at: 0.5))
    }

    private var seatsLine: String { passes.map(\.seat).filter { !$0.isEmpty }.joined(separator: " · ") }

    /// A trip: when and where it leaves, where it goes, the number, the platform or gate.
    private func tripGrid(_ p: Pass) -> some View {
        let m = p.transitMode
        return Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
            GridRow {
                FieldLabel(title: "Date", value: p.dateLabel)
                FieldLabel(title: "Departs", value: p.timeLabel, mono: true)
            }
            GridRow {
                Button { if !p.venue.isEmpty { Maps.open(p.venue) } } label: {
                    FieldLabel(title: "From", value: p.venue.isEmpty ? "" : p.venue + "  ›")
                }
                .buttonStyle(.plain)
                FieldLabel(title: "To", value: p.destination)
            }
            GridRow {
                FieldLabel(title: "Arrives", value: p.arrival.isEmpty ? "" : p.arrival + (p.arrivalDate.map { Calendar.current.isDate($0, inSameDayAs: p.start ?? $0) ? "" : " +1" } ?? ""), mono: true)
                FieldLabel(title: m.tripLabel, value: [p.carrier, p.trip].filter { !$0.isEmpty }.joined(separator: " "), mono: true)
            }
            GridRow {
                FieldLabel(title: m.gateLabel, value: p.gate, mono: true)
                FieldLabel(title: passes.count > 1 ? "Seats" : "Seat", value: seatsLine, mono: true)
            }
        }
    }

    private func timeRange(_ p: Pass) -> String {
        guard !p.timeTBD else { return "TBD" }
        guard let r = p.runtime, let s = p.start else { return p.time }
        return p.time + " – " + PassTimes.clock(s.addingTimeInterval(Double(r) * 60))
    }

    private func extras(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if p.photo != nil { chip("The stub", "photo") { photoFor = p } }
                if !p.isArchived && p.start != nil { chip("Countdown", "timer") { countdown = true } }
                chip("Edit", "pencil") { editing = p }
            }
            if let o = p.overview {
                Text(o).font(Theme.sans(15)).foregroundStyle(Theme.ink.opacity(0.8)).lineSpacing(3).padding(.horizontal, 6)
            }
            if p.confidence > 0 {
                Text("Read from the stub with \(Int(p.confidence * 100))% confidence").font(Theme.mono(11)).foregroundStyle(Theme.muted).padding(.horizontal, 6)
            }
        }
    }

    private func chip(_ t: String, _ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Label(t, systemImage: icon).font(Theme.sans(14, .medium)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 16).frame(height: 42).glass(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
    }
}

/// The code on the stub, when the photo had one.
struct CodeTile: View {
    let passes: [Pass]
    var side: CGFloat = 122

    var body: some View {
        let p = passes.first(where: { DoorView.code(for: $0) != nil }) ?? passes.first
        HStack(spacing: 16) {
            if let found = DoorView.code(for: p) {
                Image(uiImage: found.0).interpolation(.none).resizable().scaledToFit()
                    .padding(10).frame(width: side, height: side).background(Theme.paper, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 5) {
                    Text("From your ticket").font(Theme.sans(15, .medium)).foregroundStyle(Theme.ink)
                    if let seller = p?.seller, seller.rotatingCode {
                        Text("Read off your screenshot. \(seller.name) codes change every few seconds, so this one may not scan; the \(seller.name) app always will.")
                            .font(Theme.sans(13)).foregroundStyle(Theme.ink.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("The code printed on the stub, read off your photo. Scans at the door.")
                            .font(Theme.sans(13)).foregroundStyle(Theme.ink.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(p?.photo != nil ? "No readable code on this ticket. Show the stub photo at the door." : "No code on this ticket.")
                    .font(Theme.sans(13)).foregroundStyle(Theme.muted)
            }
        }
    }
}

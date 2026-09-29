import SwiftUI
import SwiftData

/// One showing: the film's art filling the top, the title on it, and a glass stub holding
/// the details, the ticket's code and the button for the door.
struct DetailView: View {
    let group: UUID
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var importer: Importer
    @Query private var passes: [Pass]
    @State private var editing: Pass?
    @State private var photoFor: Pass?
    @State private var door = false
    @State private var countdown = false
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
                    ZStack(alignment: .top) {
                        CoverArt(pass: p, preferBackdrop: p.backdropPath != nil).frame(height: 500).frame(maxWidth: .infinity)
                        LinearGradient(stops: [.init(color: Theme.bg.opacity(0.4), location: 0), .init(color: .clear, location: 0.22),
                                               .init(color: Theme.bg.opacity(0.9), location: 0.8), .init(color: Theme.bg, location: 1)],
                                       startPoint: .top, endPoint: .bottom).frame(height: 500)
                        VStack(alignment: .leading, spacing: 0) {
                            Spacer().frame(height: 270)
                            titleBlock(p).padding(.horizontal, 22)
                            panel(p).padding(.horizontal, 16).padding(.top, 18)
                            extras(p).padding(.horizontal, 16).padding(.top, 14)
                        }
                        .padding(.bottom, 60)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
            } else {
                Text("This ticket is gone.").font(Theme.serif(28)).foregroundStyle(Theme.muted)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if let p = passes.first { Button { editing = p } label: { Label("Edit", systemImage: "pencil") } }
                    if passes.first?.kind == .movie { Button { picking = true } label: { Label("Pick the film", systemImage: "film") } }
                    Button { merging = true } label: { Label("Merge with another ticket", systemImage: "rectangle.stack.badge.plus") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis") }
                .accessibilityLabel("More")
            }
        }
        .sheet(item: $editing) { EditView(pass: $0) }
        .fullScreenCover(item: $photoFor) { p in PhotoViewer(data: p.photo) }
        .fullScreenCover(isPresented: $door) { DoorView(passes: passes) }
        .fullScreenCover(isPresented: $countdown) { CountdownView(passes: passes) }
        .sheet(isPresented: $picking) { if let p = passes.first { MoviePicker(passes: passes, query: p.title).environmentObject(importer) } }
        .sheet(isPresented: $merging) { MergePicker(into: passes) }
        .confirmationDialog("Delete \(passes.count == 1 ? "this ticket" : "these \(passes.count) tickets")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                for p in passes { Reminders.cancel(p.id); ctx.delete(p) }
                try? ctx.save()
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
        var s = ["FILM", "GAME", "CONCERT"][[EventKind.movie, .sports, .concert].firstIndex(of: p.kind) ?? 0]
        if let r = p.runtime { s += " · \(r / 60)H \(r % 60)M" }
        return s
    }

    private func panel(_ p: Pass) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            TimelineView(.periodic(from: .now, by: 30)) { c in
                if let s = Countdown.short(to: p.start, now: c.date), !p.isArchived {
                    Text("STARTS \(s)").font(Theme.mono(12)).tracking(1.4).foregroundStyle(Theme.amber)
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
                GridRow {
                    FieldLabel(title: "Date", value: PassTimes.humanDate(p.date) ?? "")
                    FieldLabel(title: "Time", value: timeRange(p), mono: true)
                }
                GridRow {
                    Button { if !p.venue.isEmpty { Maps.open(p.venue) } } label: {
                        FieldLabel(title: "Venue", value: p.venue.isEmpty ? "" : p.venue + "  ›")
                    }
                    .buttonStyle(.plain)
                    FieldLabel(title: passes.count > 1 ? "Seats" : "Seat", value: Showings.seats(passes).replacingOccurrences(of: " ", with: " · "), mono: true)
                }
            }
            Perforation().padding(.horizontal, -8).padding(.vertical, 2)
            CodeTile(passes: passes)
            Button { door = true } label: {
                Label("Show at the door", systemImage: "sun.max").font(Theme.sans(16, .semibold)).foregroundStyle(Theme.onAccent)
                    .frame(maxWidth: .infinity, minHeight: 52).background(Theme.accent, in: Capsule())
            }
            .disabled(DoorView.code(for: passes.first) == nil && passes.allSatisfy { $0.photo == nil })
        }
        .padding(.horizontal, 22).padding(.vertical, 22)
        .glass(in: StubShape(corner: 28, notch: 14, at: 0.5))
    }

    private func timeRange(_ p: Pass) -> String {
        guard !p.time.isEmpty else { return "" }
        guard let r = p.runtime, let s = p.start else { return p.time }
        return p.time + " – " + s.addingTimeInterval(Double(r) * 60).formatted(date: .omitted, time: .shortened)
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

/// The code on the stub: the real one when the photo had it, else drawn from the reference.
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
                    Text(found.1 ? "From your ticket" : "Generated").font(Theme.sans(15, .medium)).foregroundStyle(Theme.ink)
                    Text(found.1 ? "The code printed on the stub, read off your photo. Scans at the door."
                                 : "Drawn from \(p?.bookingCode ?? ""). Scans only if the venue used this reference.")
                        .font(Theme.sans(13)).foregroundStyle(Theme.ink.opacity(0.78)).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("No code on this ticket. Add the booking reference in Edit, or show the stub photo at the door.")
                    .font(Theme.sans(13)).foregroundStyle(Theme.muted)
            }
        }
    }
}

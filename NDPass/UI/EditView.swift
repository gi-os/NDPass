import SwiftUI
import SwiftData

struct EditView: View {
    @Bindable var pass: Pass
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var title = ""
    @State private var venue = ""
    @State private var date = ""
    @State private var time = ""
    @State private var seat = ""
    @State private var price = ""
    @State private var code = ""
    @State private var kind: EventKind = .movie
    @State private var seller: Seller?
    @State private var mode: TransitMode = .train
    @State private var carrier = ""
    @State private var trip = ""
    @State private var destination = ""
    @State private var arrival = ""
    @State private var gate = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Kind", selection: $kind) { ForEach(EventKind.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) } }
                    TextField(kind == .transit ? "Route (New York → Boston)" : "Title", text: $title)
                    TextField(kind == .transit ? "From (station or airport)" : "Venue", text: $venue)
                    Picker("Sold by", selection: $seller) {
                        Text("—").tag(Seller?.none)
                        ForEach(Seller.allCases, id: \.self) { Text($0.name).tag(Seller?.some($0)) }
                    }
                }
                if kind == .transit {
                    Section("Trip") {
                        Picker("Mode", selection: $mode) { ForEach(TransitMode.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) } }
                        TextField("To (station or airport)", text: $destination)
                        TextField("Carrier (Amtrak, United…)", text: $carrier)
                        TextField("\(mode.tripLabel) number", text: $trip).autocorrectionDisabled().textInputAutocapitalization(.characters)
                        TextField(mode.gateLabel, text: $gate).autocorrectionDisabled().textInputAutocapitalization(.characters)
                    }
                }
                Section {
                    DateField(text: $date)
                    TimeField(label: kind == .transit ? "Departs" : "Time", text: $time)
                    if kind == .transit { TimeField(label: "Arrives", text: $arrival) }
                }
                Section {
                    TextField("Seat", text: $seat)
                    TextField("Price", text: $price)
                    TextField("Booking reference", text: $code).autocorrectionDisabled().textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Edit ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .onAppear {
                title = pass.title; venue = pass.venue; date = pass.date; time = pass.time
                seat = pass.seat; price = pass.price; code = pass.bookingCode; kind = pass.kind; seller = pass.seller
                mode = pass.transitMode; carrier = pass.carrier; trip = pass.trip
                destination = pass.destination; arrival = pass.arrival; gate = pass.gate
            }
        }
    }

    private func save() {
        pass.title = title.trimmingCharacters(in: .whitespaces)
        pass.venue = venue.trimmingCharacters(in: .whitespaces)
        pass.date = TicketDate.resolveTyped(date) ?? ""
        pass.time = PassTimes.normalizeTime(time, literal: kind == .transit) ?? ""
        pass.seat = seat
        pass.price = price
        pass.bookingCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        pass.kind = kind
        pass.seller = seller
        if kind == .transit {
            pass.transitMode = mode
            pass.carrier = carrier.trimmingCharacters(in: .whitespaces)
            pass.trip = trip.trimmingCharacters(in: .whitespaces)
            pass.destination = destination.trimmingCharacters(in: .whitespaces)
            pass.arrival = PassTimes.normalizeTime(arrival, literal: true) ?? ""
            pass.gate = gate.trimmingCharacters(in: .whitespaces)
            if pass.title.isEmpty || pass.title == "Untitled", let r = Transit.route(pass.venue, pass.destination) { pass.title = r }
        }
        try? ctx.save()
        Reminders.schedule(pass)
        dismiss()
    }
}

/// Correct the poster when the parser matched the wrong film.
struct MoviePicker: View {
    let passes: [Pass]
    @State var query: String
    @EnvironmentObject private var importer: Importer
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var results: [MovieMatch] = []
    @State private var loading = false

    var body: some View {
        NavigationStack {
            List(results) { m in
                Button { choose(m) } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: m.posterURL) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
                            .frame(width: 46, height: 68).clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading) { Text(m.title).font(.headline); Text(m.year).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            .overlay { if loading { ProgressView() } else if results.isEmpty { Text(Keys.get(.tmdb) == nil ? "Add a TMDb key in Settings to search films." : "No films found.").foregroundStyle(.secondary) } }
            .searchable(text: $query)
            .onSubmit(of: .search) { Task { await search() } }
            .task { await search() }
            .navigationTitle("Pick the film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func search() async {
        loading = true
        results = await TMDb.search(query, key: Keys.get(.tmdb))
        loading = false
    }

    private func choose(_ m: MovieMatch) {
        Task {
            let runtime = await TMDb.runtime(m.id, key: Keys.get(.tmdb))
            for p in passes { importer.apply(m, to: p); p.title = m.title; p.runtime = runtime; p.logoPath = nil }
            if let first = passes.first { await TMDb.art(for: first, key: Keys.get(.tmdb)); for p in passes.dropFirst() { p.logoPath = first.logoPath; p.backdropPath = first.backdropPath } }
            try? ctx.save()
            dismiss()
        }
    }
}

/// Fold another ticket into this showing — for tickets added before grouping existed or read
/// too differently to match. This showing's kind and film win.
struct MergePicker: View {
    let into: [Pass]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query(sort: \Pass.createdAt, order: .reverse) private var all: [Pass]

    var body: some View {
        let target = into.first
        let others = Dictionary(grouping: all.filter { $0.group != target?.group }, by: \.group).values.map { $0 }
        NavigationStack {
            List(others, id: \.first!.group) { g in
                Button { merge(g) } label: { TicketCard(passes: g) }.listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .navigationTitle("Merge into this showing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func merge(_ g: [Pass]) {
        guard let t = into.first else { return }
        for p in g {
            p.group = t.group; p.kind = t.kind; p.title = t.title
            p.tmdbID = t.tmdbID; p.posterPath = t.posterPath; p.backdropPath = t.backdropPath; p.overview = t.overview; p.runtime = t.runtime
        }
        try? ctx.save()
        dismiss()
    }
}

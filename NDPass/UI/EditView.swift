import SwiftUI
import SwiftData

/// Edit a showing: what it is, where and when for all its tickets at once, and each ticket's
/// seat, price and reference. Also used to type a ticket in by hand (`isNew`).
struct EditView: View {
    let passes: [Pass]
    var isNew = false
    var start = 0
    var onSaved: (Pass) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var importer: Importer
    @State private var title = ""
    @State private var venue = ""
    @State private var date = ""
    @State private var time = ""
    @State private var kind: EventKind = .movie
    @State private var seller: Seller?
    @State private var mode: TransitMode = .train
    @State private var carrier = ""
    @State private var trip = ""
    @State private var destination = ""
    @State private var arrival = ""
    @State private var gate = ""
    @State private var seats: [String] = []
    @State private var prices: [String] = []
    @State private var codes: [String] = []
    @State private var ticket = 0

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
                if seats.indices.contains(ticket) {
                    Section {
                        if passes.count > 1 {
                            Picker("Ticket", selection: $ticket) {
                                ForEach(seats.indices, id: \.self) { i in Text(seats[i].isEmpty ? "Ticket \(i + 1)" : seats[i]).tag(i) }
                            }
                        }
                        TextField("Seat", text: $seats[ticket])
                        TextField("Price", text: $prices[ticket])
                        TextField("Booking reference", text: $codes[ticket]).autocorrectionDisabled().textInputAutocapitalization(.never)
                    } header: { if passes.count > 1 { Text("Each ticket") } }
                }
            }
            .navigationTitle(isNew ? "New ticket" : "Edit ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Save") { save() }.bold()
                        .disabled(isNew && title.trimmingCharacters(in: .whitespaces).isEmpty && venue.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let pass = passes.first, seats.isEmpty else { return }
        title = pass.title == "Untitled" ? "" : pass.title; venue = pass.venue; date = pass.date; time = pass.time
        kind = pass.kind; seller = pass.seller
        mode = pass.transitMode; carrier = pass.carrier; trip = pass.trip
        destination = pass.destination; arrival = pass.arrival; gate = pass.gate
        seats = passes.map(\.seat); prices = passes.map(\.price); codes = passes.map(\.bookingCode)
        ticket = min(max(0, start), passes.count - 1)
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        for (i, pass) in passes.enumerated() {
            pass.title = t.isEmpty ? "Untitled" : t
            pass.venue = venue.trimmingCharacters(in: .whitespaces)
            pass.date = TicketDate.resolveTyped(date) ?? ""
            // Picked with the time picker, so taken as given (a 6:30 AM tour is real).
            pass.time = PassTimes.normalizeTime(time, literal: true) ?? ""
            pass.kind = kind
            pass.seller = seller
            if seats.indices.contains(i) {
                pass.seat = seats[i].trimmingCharacters(in: .whitespaces)
                pass.price = prices[i].trimmingCharacters(in: .whitespaces)
                pass.bookingCode = codes[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if kind == .transit {
                pass.transitMode = mode
                pass.carrier = carrier.trimmingCharacters(in: .whitespaces)
                pass.trip = trip.trimmingCharacters(in: .whitespaces)
                pass.destination = destination.trimmingCharacters(in: .whitespaces)
                pass.arrival = PassTimes.normalizeTime(arrival, literal: true) ?? ""
                pass.gate = gate.trimmingCharacters(in: .whitespaces)
                if pass.title == "Untitled", let r = Transit.route(pass.venue, pass.destination) { pass.title = r }
            }
        }
        guard let first = passes.first else { dismiss(); return }
        if isNew {
            importer.file(first, into: ctx)
            // The poster or art, as if it had been scanned.
            Task { await importer.decorate(first); try? ctx.save() }
        } else {
            try? ctx.save()
        }
        onSaved(first)
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
        let others = Showings.groups(all.filter { $0.group != target?.group }, archived: nil)
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
        // Everything about the showing comes from this one; each ticket keeps its own seat,
        // price, reference, photo and code.
        for p in g {
            p.group = t.group; p.kind = t.kind; p.title = t.title
            p.venue = t.venue; p.date = t.date; p.time = t.time; p.sellerRaw = t.sellerRaw
            p.tmdbID = t.tmdbID; p.posterPath = t.posterPath; p.backdropPath = t.backdropPath; p.logoPath = t.logoPath
            p.overview = t.overview; p.runtime = t.runtime; p.art = t.art
            p.transitModeRaw = t.transitModeRaw; p.carrier = t.carrier; p.trip = t.trip
            p.destination = t.destination; p.arrival = t.arrival; p.gate = t.gate
        }
        try? ctx.save()
        dismiss()
    }
}

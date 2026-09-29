import SwiftUI
import SwiftData

/// Pick the artist by hand when the photo is the wrong act, like Pick the film.
struct ArtistPicker: View {
    let passes: [Pass]
    @State var query: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var results: [Artists.Hit] = []
    @State private var loading = false
    @State private var saving = false

    var body: some View {
        NavigationStack {
            List(results) { a in
                Button { choose(a) } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: a.thumb) { $0.resizable().scaledToFill() } placeholder: { Color.gray.opacity(0.2) }
                            .frame(width: 56, height: 56).clipShape(Circle())
                        VStack(alignment: .leading) {
                            Text(a.name).font(.headline)
                            Text("\(a.fans.formatted()) fans").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(saving)
            }
            .overlay { if loading || saving { ProgressView() } else if results.isEmpty { Text("No artists found.").foregroundStyle(.secondary) } }
            .searchable(text: $query)
            .onSubmit(of: .search) { Task { await search() } }
            .task { await search() }
            .navigationTitle("Pick the artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func search() async {
        loading = true
        results = await Artists.search(query)
        loading = false
    }

    private func choose(_ a: Artists.Hit) {
        saving = true
        Task {
            var art: Data?
            if let u = a.photo, let (d, _) = try? await URLSession.shared.data(from: u) { art = d }
            for p in passes { p.title = a.name; if let art { p.art = art } }
            try? ctx.save()
            dismiss()
        }
    }
}

/// Pick both teams by hand when the crests or colors came out wrong.
struct TeamPicker: View {
    let passes: [Pass]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @State private var side = 0
    @State private var queries: [String]
    @State private var picks: [Team?] = [nil, nil]
    @State private var results: [Team] = []
    @State private var loading = false
    @State private var saving = false

    init(passes: [Pass]) {
        self.passes = passes
        let names = Matchup.split(passes.first?.title) ?? (passes.first?.title ?? "", "")
        _queries = State(initialValue: [names.0, names.1])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Team", selection: $side) {
                        Text(picks[0]?.name ?? (queries[0].isEmpty ? "Team 1" : queries[0])).tag(0)
                        Text(picks[1]?.name ?? (queries[1].isEmpty ? "Team 2" : queries[1])).tag(1)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(results) { t in
                        Button { picks[side] = t; if side == 0 && picks[1] == nil { side = 1 } } label: {
                            HStack(spacing: 12) {
                                AsyncImage(url: t.badge.flatMap { URL(string: $0.absoluteString + "/small") }) { $0.resizable().scaledToFit() } placeholder: { Color.gray.opacity(0.15) }
                                    .frame(width: 44, height: 44)
                                VStack(alignment: .leading) {
                                    Text(t.name).font(.headline)
                                    Text(t.league.isEmpty ? " " : t.league).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if picks[side]?.id == t.id { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                }
            }
            .overlay {
                if loading || saving { ProgressView() }
                else if Keys.get(.sportsdb) == nil { Text("Add a TheSportsDB key in Settings to search teams.").foregroundStyle(.secondary).multilineTextAlignment(.center).padding() }
                else if results.isEmpty { Text("No teams found.").foregroundStyle(.secondary) }
            }
            .searchable(text: $queries[side], prompt: side == 0 ? "Team 1" : "Team 2")
            .onSubmit(of: .search) { Task { await search() } }
            .task(id: side) { await search() }
            .navigationTitle("Pick the teams")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { save() }.bold().disabled(picks[0] == nil || picks[1] == nil || saving) }
            }
        }
    }

    private func search() async {
        guard let key = Keys.get(.sportsdb) else { return }
        loading = true
        results = await Teams.lookup(queries[side], key: key)
        loading = false
    }

    private func save() {
        guard let a = picks[0], let b = picks[1] else { return }
        saving = true
        Task {
            let art = await EventArt.game(a, b)
            for p in passes { p.title = "\(a.name) vs \(b.name)"; if let art { p.art = art } }
            try? ctx.save()
            dismiss()
        }
    }
}

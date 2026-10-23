import SwiftUI
import SwiftData

/// Every stub you've kept, as a grid of tickets. On the iPhone Duo's inner display, open: the
/// grid on the left half and the picked ticket on the right.
struct CollectionView: View {
    @Query(sort: \Pass.createdAt) private var passes: [Pass]
    @State private var filter = "All"
    @State private var selected: UUID?

    private var years: [String] {
        Array(Set(passes.compactMap { PassTimes.day($0.date) != nil ? String($0.date.prefix(4)) : nil })).sorted(by: >)
    }

    /// One chip per kind you actually have, besides films.
    private var kindFilters: [String] {
        let have = Set(passes.map(\.kind))
        guard have.count > 1 else { return [] }
        return EventKind.allCases.filter { have.contains($0) }.map(\.plural)
    }

    private var groups: [[Pass]] {
        Showings.groups(passes, archived: nil).filter { g in
            let p = g[0]
            switch filter {
            case "All": return true
            default:
                if let k = EventKind.allCases.first(where: { $0.plural == filter }) { return p.kind == k }
                return p.date.hasPrefix(filter)
            }
        }
        .sorted { $0[0].listDate > $1[0].listDate }
    }

    var body: some View {
        if Duo.shared.fold == .open {
            let id = selected ?? groups.first?.first?.group
            ZStack {
                FoldBackdrop(pass: groups.first(where: { $0.first?.group == id })?.first)
                HingeSplit {
                    // No NavigationStack of its own: one picked up the side tab bar's inset and
                    // left a dead band before the hinge.
                    grid(columns: 2)
                } second: {
                    NavigationStack {
                        if let id { DetailView(group: id, artBehind: true).id(id) }
                        else { Text("Pick a ticket").font(Theme.serif(30)).foregroundStyle(Theme.muted).containerBackground(.clear, for: .navigation) }
                    }
                }
            }
        } else {
            NavigationStack {
                grid(columns: nil)
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationDestination(for: UUID.self) { DetailView(group: $0) }
            }
        }
    }

    /// `columns` set: a fixed grid whose stubs pick the ticket beside it instead of opening it.
    private func grid(columns: Int?) -> some View {
        let picking = columns != nil
        let current = selected ?? groups.first?.first?.group
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Collection").font(Theme.serif(42)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(passes.count == 1 ? "1 STUB" : "\(passes.count) STUBS").font(Theme.mono(12)).foregroundStyle(Theme.muted)
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(["All"] + years + kindFilters, id: \.self) { f in
                            Button { withAnimation(.snappy) { filter = f; selected = nil } } label: {
                                Text(f).font(Theme.sans(14, .medium)).padding(.horizontal, 16).frame(height: 36)
                                    .foregroundStyle(filter == f ? Theme.paperInk : Theme.ink)
                                    .background { if filter == f { Capsule().fill(Theme.ink) } else { Color.clear.glass(in: Capsule(), interactive: true) } }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                if groups.isEmpty {
                    Text("Nothing here yet.").font(Theme.sans(15)).foregroundStyle(Theme.muted).padding(.top, 40)
                }
                LazyVGrid(columns: columns.map { Array(repeating: GridItem(.flexible(), spacing: 12), count: $0) } ?? [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 16) {
                    ForEach(groups, id: \.first!.group) { g in
                        if picking {
                            Button { selected = g[0].group } label: {
                                StubThumb(passes: g)
                                    .overlay { if current == g[0].group { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.accent, lineWidth: 2).padding(-4) } }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(value: g[0].group) { StubThumb(passes: g) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 120)
        }
        // Open on the iPhone Duo the art shows through from behind.
        .background(picking ? Color.clear : Theme.bg)
    }
}

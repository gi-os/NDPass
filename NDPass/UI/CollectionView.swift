import SwiftUI
import SwiftData

/// Every stub you've kept, as a grid of tickets.
struct CollectionView: View {
    @Query(sort: \Pass.createdAt) private var passes: [Pass]
    @State private var filter = "All"

    private var years: [String] {
        Array(Set(passes.compactMap { $0.date.count >= 4 ? String($0.date.prefix(4)) : nil })).sorted(by: >)
    }

    private var groups: [[Pass]] {
        Showings.groups(passes, archived: nil).filter { g in
            let p = g[0]
            switch filter {
            case "All": return true
            case "Games": return p.kind == .sports
            case "Concerts": return p.kind == .concert
            default: return p.date.hasPrefix(filter)
            }
        }
        .sorted { $0[0].sortDate > $1[0].sortDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Collection").font(Theme.serif(42)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(passes.count) STUBS").font(Theme.mono(12)).foregroundStyle(Theme.muted)
                    }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(["All"] + years + ["Games", "Concerts"], id: \.self) { f in
                                Button { withAnimation(.snappy) { filter = f } } label: {
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 16) {
                        ForEach(groups, id: \.first!.group) { g in
                            NavigationLink(value: g[0].group) { StubThumb(passes: g) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 120)
            }
            .background(Theme.bg)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { DetailView(group: $0) }
        }
    }
}

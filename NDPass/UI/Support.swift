import StoreKit
import SwiftUI
import UIKit

/// NDPass is free, with nothing locked. Gold and Gold Plus are one-time purchases that support
/// it, the way PPSSPP Gold does: Gold adds a gold app icon, Gold Plus adds a rare platinum one
/// too, and both add a thank-you badge. Nothing else changes.
@MainActor
final class Supporter: ObservableObject {
    static let shared = Supporter()

    enum Tier: Int, Comparable {
        case none = 0, gold, goldPlus
        static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
        var name: String { self == .goldPlus ? "Gold Plus" : self == .gold ? "Gold" : "" }
    }

    static let goldID = "com.gios.ndpass.gold"
    static let goldPlusID = "com.gios.ndpass.goldplus"
    static func tier(for productID: String) -> Tier {
        productID == goldPlusID ? .goldPlus : productID == goldID ? .gold : .none
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var tier: Tier
    @Published private(set) var busy = false
    @Published var message: String?
    private var listener: Task<Void, Never>?

    private static let cacheKey = "supporterTier"
    private init() { tier = Tier(rawValue: Store.defaults.integer(forKey: Self.cacheKey)) ?? .none }

    /// Once, at launch: listen for purchases made elsewhere (another device, Ask to Buy,
    /// a refund) and check what's owned.
    func start() {
        guard listener == nil, !Demo.active else { return }
        listener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        Task { await load(); await refresh() }
    }

    /// Settings shows Support NDPass only when there's something to show: the purchases came
    /// back from the App Store, or you already own one. Until the App Store has them (offline,
    /// or before they're approved), there's no locked icon you can't buy.
    var showsSupport: Bool { Demo.active || !products.isEmpty || tier > .none }

    func load() async {
        guard products.isEmpty, !Demo.active else { return }
        if let p = try? await Product.products(for: [Self.goldID, Self.goldPlusID]) {
            products = p.sorted { $0.price < $1.price }
        }
    }

    /// What you own, from Apple's records (a refunded purchase drops out).
    func refresh() async {
        var owned: Tier = .none
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            owned = max(owned, Self.tier(for: t.productID))
        }
        tier = owned
        Store.defaults.set(owned.rawValue, forKey: Self.cacheKey)
        // An icon you no longer own goes back to the standard one.
        if AppIcon.current.tier > owned { AppIcon.set(.standard) }
    }

    func buy(_ product: Product) async {
        busy = true; defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let t) = result else { message = "Apple couldn't verify that purchase."; return }
                await t.finish()
                await refresh()
                message = "Thank you for supporting NDPass."
            case .pending: message = "Waiting for approval. Your icon unlocks as soon as it goes through."
            case .userCancelled: break
            @unknown default: break
            }
        } catch {
            message = "The purchase didn't go through. \(error.localizedDescription)"
        }
    }

    func restore() async {
        busy = true; defer { busy = false }
        try? await AppStore.sync()
        await refresh()
        message = tier == .none ? "No NDPass Gold purchase found for this Apple Account." : "Restored NDPass \(tier.name)."
    }
}

/// The app icons: the standard one, gold (Gold) and platinum (Gold Plus).
enum AppIcon: String, CaseIterable, Identifiable {
    case standard, gold, platinum
    var id: String { rawValue }
    var assetName: String? { self == .standard ? nil : self == .gold ? "AppIconGold" : "AppIconPlatinum" }
    var preview: String { self == .standard ? "IconStandard" : self == .gold ? "IconGold" : "IconPlatinum" }
    var title: String { self == .standard ? "Classic" : self == .gold ? "Gold" : "Platinum" }
    var tier: Supporter.Tier { self == .standard ? .none : self == .gold ? .gold : .goldPlus }

    @MainActor static var current: AppIcon {
        allCases.first { $0.assetName == UIApplication.shared.alternateIconName } ?? .standard
    }
    @MainActor static func set(_ icon: AppIcon) {
        guard UIApplication.shared.supportsAlternateIcons, current != icon else { return }
        UIApplication.shared.setAlternateIconName(icon.assetName)
    }
}

/// Settings > Support NDPass: the badge, the icons, the two purchases and Restore.
struct SupportSection: View {
    @ObservedObject var store = Supporter.shared
    @State private var icon = AppIcon.current

    /// The demo (store screenshots, App Review's purchase screenshot) shows the real layout
    /// with the real prices, since a simulator has no App Store to ask.
    private struct Row: Identifiable { let id: String; let title: String; let detail: String; let price: String; let product: Product? }
    private var rows: [Row] {
        if Demo.active {
            return [Row(id: Supporter.goldID, title: "NDPass Gold", detail: "A gold app icon and a thank-you.", price: "$4.99", product: nil),
                    Row(id: Supporter.goldPlusID, title: "NDPass Gold Plus", detail: "Gold, plus a rare platinum icon.", price: "$14.99", product: nil)]
        }
        return store.products.map { Row(id: $0.id, title: $0.displayName, detail: $0.description, price: $0.displayPrice, product: $0) }
    }

    var body: some View {
        if store.tier > .none {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").foregroundStyle(store.tier == .goldPlus ? Color(red: 0.72, green: 0.62, blue: 1) : Color(red: 0.96, green: 0.78, blue: 0.3))
                Text("NDPass \(store.tier.name) supporter. Thank you!").font(Theme.sans(15, .medium))
            }
        }
        HStack(spacing: 14) {
            ForEach(AppIcon.allCases) { i in
                let owned = i.tier <= store.tier
                Button {
                    if owned { AppIcon.set(i); icon = i }
                } label: {
                    VStack(spacing: 6) {
                        Image(i.preview).resizable().scaledToFit()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(icon == i ? Theme.accent : .clear, lineWidth: 2.5))
                            .overlay(alignment: .bottomTrailing) {
                                if !owned { Image(systemName: "lock.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(.white).padding(5).background(.black.opacity(0.6), in: Circle()).offset(x: 4, y: 4) }
                            }
                            .opacity(owned ? 1 : 0.55)
                        Text(i.title).font(Theme.sans(12)).foregroundStyle(owned ? Theme.ink : Theme.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(i.title + (owned ? (icon == i ? ", selected" : "") : ", locked"))
            }
        }
        .padding(.vertical, 4)
        ForEach(rows) { r in
            let owned = Supporter.tier(for: r.id) <= store.tier
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.title).font(Theme.sans(15, .medium))
                    Text(r.detail).font(Theme.sans(12)).foregroundStyle(Theme.muted)
                }
                Spacer()
                if owned {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.accent).accessibilityLabel("Owned")
                } else {
                    Button(r.price) { if let p = r.product { Task { await store.buy(p) } } }
                        .buttonStyle(.borderedProminent).tint(Theme.accent).disabled(store.busy)
                }
            }
        }
        if !rows.isEmpty || store.tier > .none {
            Button("Restore Purchases") { Task { await store.restore() } }.disabled(store.busy)
        }
        if let m = store.message {
            Text(m).font(Theme.sans(13)).foregroundStyle(Theme.muted)
        }
    }
}

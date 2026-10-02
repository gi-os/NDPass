import UIKit

/// Who sold the ticket, and how to get back to it. Tickets with codes that rotate every few
/// seconds (Ticketmaster SafeTix, DICE, AXS Mobile ID, SeatGeek) can only be shown by their
/// own app, so for those NDPass hands you over instead of drawing a code.
enum Seller: String, CaseIterable, Codable {
    case ticketmaster, livenation, dice, axs, seatgeek, eventbrite, stubhub, fandango, amc, regal, atom, alamo, eventim, universe

    var name: String {
        switch self {
        case .ticketmaster: return "Ticketmaster"
        case .livenation: return "Live Nation"
        case .dice: return "DICE"
        case .axs: return "AXS"
        case .seatgeek: return "SeatGeek"
        case .eventbrite: return "Eventbrite"
        case .stubhub: return "StubHub"
        case .fandango: return "Fandango"
        case .amc: return "AMC"
        case .regal: return "Regal"
        case .atom: return "Atom"
        case .alamo: return "Alamo Drafthouse"
        case .eventim: return "Eventim"
        case .universe: return "Universe"
        }
    }

    /// Words on the ticket, in the email or in the link that give it away.
    var clues: [String] {
        switch self {
        case .ticketmaster: return ["ticketmaster", "safetix"]
        case .livenation: return ["live nation", "livenation"]
        case .dice: return ["dice.fm", "dice"]
        case .axs: return ["axs.com", "axs mobile id", " axs "]
        case .seatgeek: return ["seatgeek"]
        case .eventbrite: return ["eventbrite"]
        case .stubhub: return ["stubhub"]
        case .fandango: return ["fandango"]
        case .amc: return ["amc theatres", "amctheatres", "amc "]
        case .regal: return ["regal", "regmovies"]
        case .atom: return ["atom tickets", "atomtickets"]
        case .alamo: return ["alamo drafthouse", "drafthouse"]
        case .eventim: return ["eventim"]
        case .universe: return ["universe.com"]
        }
    }

    var hosts: [String] {
        switch self {
        case .ticketmaster: return ["ticketmaster.com", "ticketmaster.ca", "ticketmaster.co.uk"]
        case .livenation: return ["livenation.com"]
        case .dice: return ["dice.fm", "link.dice.fm"]
        case .axs: return ["axs.com"]
        case .seatgeek: return ["seatgeek.com"]
        case .eventbrite: return ["eventbrite.com"]
        case .stubhub: return ["stubhub.com"]
        case .fandango: return ["fandango.com"]
        case .amc: return ["amctheatres.com"]
        case .regal: return ["regmovies.com"]
        case .atom: return ["atomtickets.com"]
        case .alamo: return ["drafthouse.com"]
        case .eventim: return ["eventim.de", "eventim.co.uk"]
        case .universe: return ["universe.com"]
        }
    }

    /// Where your tickets are. These are https links, which open the seller's app when it's
    /// installed (universal links) and their site when it isn't.
    var ticketsURL: URL {
        switch self {
        case .ticketmaster: return URL(string: "https://www.ticketmaster.com/user/orders")!
        case .livenation: return URL(string: "https://www.livenation.com/account/tickets")!
        case .dice: return URL(string: "https://dice.fm/")!
        case .axs: return URL(string: "https://www.axs.com/")!
        case .seatgeek: return URL(string: "https://seatgeek.com/account/tickets")!
        case .eventbrite: return URL(string: "https://www.eventbrite.com/mytickets/")!
        case .stubhub: return URL(string: "https://www.stubhub.com/my/orders")!
        case .fandango: return URL(string: "https://www.fandango.com/")!
        case .amc: return URL(string: "https://www.amctheatres.com/")!
        case .regal: return URL(string: "https://www.regmovies.com/")!
        case .atom: return URL(string: "https://www.atomtickets.com/")!
        case .alamo: return URL(string: "https://drafthouse.com/")!
        case .eventim: return URL(string: "https://www.eventim.de/")!
        case .universe: return URL(string: "https://www.universe.com/")!
        }
    }

    /// The seller's app, opened straight to it when a link won't do.
    var appURL: URL? {
        switch self {
        case .ticketmaster: return URL(string: "ticketmaster://")
        case .livenation: return URL(string: "livenation://")
        case .dice: return URL(string: "dice://")
        case .axs: return URL(string: "axs://")
        case .seatgeek: return URL(string: "seatgeek://")
        case .eventbrite: return URL(string: "eventbrite://")
        case .stubhub: return URL(string: "stubhub://")
        case .fandango: return URL(string: "fandango://")
        case .atom: return URL(string: "atomtickets://")
        default: return nil
        }
    }

    /// Only this seller's app can get you in (the code rotates).
    var rotatingCode: Bool { [.ticketmaster, .livenation, .dice, .axs, .seatgeek].contains(self) }

    static func detect(text: String, url: String?) -> Seller? {
        if let host = url.flatMap({ URL(string: $0)?.host?.lowercased() }),
           let s = allCases.first(where: { $0.hosts.contains { host == $0 || host.hasSuffix("." + $0) } }) { return s }
        let t = " " + text.lowercased() + " "
        return allCases.first { s in s.clues.contains { t.contains($0) } }
    }

    /// Open the order itself if we have its link from this seller, else your tickets there.
    #if !NDPASS_EXTENSION
    static func open(_ p: Pass) {
        guard let s = p.seller else { return }
        var links: [URL] = []
        if let src = p.sourceURL, let u = URL(string: src), let h = u.host?.lowercased(), s.hosts.contains(where: { h.hasSuffix($0) }) { links.append(u) }
        links.append(s.ticketsURL)
        // 1. The order or tickets link, but only if the seller's app takes it (universal link).
        // 2. The app itself, by its URL scheme. 3. The website, when the app isn't installed.
        func web() { UIApplication.shared.open(links[0]) }
        func scheme() {
            guard let a = s.appURL else { return web() }
            UIApplication.shared.open(a) { ok in if !ok { web() } }
        }
        func universal(_ i: Int) {
            guard i < links.count else { return scheme() }
            UIApplication.shared.open(links[i], options: [.universalLinksOnly: true]) { ok in if !ok { universal(i + 1) } }
        }
        universal(0)
    }
    #endif
}

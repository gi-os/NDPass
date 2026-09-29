import UIKit

/// Team colors for games, no key and no network: each half of a game ticket is painted in
/// its team's colors with the name in type. Colors only, never logos (those are the teams'
/// trademarks). Men's leagues from the open teamcolors dataset (github.com/jimniels/teamcolors);
/// women's leagues and newer teams added by hand.
enum TeamColors {
    struct Entry {
        let name: String, league: String, female: Bool, hex: [UInt32]
        init(_ n: String, _ l: String, _ f: Bool, _ h: [UInt32]) { name = n; league = l; female = f; hex = h }
        var colors: [UIColor] {
            hex.map { UIColor(red: CGFloat($0 >> 16 & 255) / 255, green: CGFloat($0 >> 8 & 255) / 255, blue: CGFloat($0 & 255) / 255, alpha: 1) }
        }
        var team: Team { Team(name: name, league: league, female: female, badge: nil, colors: colors) }
    }

    static let all: [Entry] = [
        .init("Arizona Diamondbacks", "MLB", false, [0xA71930, 0x000000]),
        .init("Atlanta Braves", "MLB", false, [0xCE1141, 0x13274F]),
        .init("Baltimore Orioles", "MLB", false, [0xDF4601, 0x000000]),
        .init("Boston Red Sox", "MLB", false, [0xBD3039, 0x0D2B56]),
        .init("Chicago Cubs", "MLB", false, [0xCC3433, 0x0E3386]),
        .init("Chicago White Sox", "MLB", false, [0x000000, 0xC4CED4]),
        .init("Cincinnati Reds", "MLB", false, [0xC6011F, 0x000000]),
        .init("Cleveland Indians", "MLB", false, [0xE31937, 0x002B5C]),
        .init("Colorado Rockies", "MLB", false, [0x333366, 0x231F20]),
        .init("Detroit Tigers", "MLB", false, [0x0C2C56]),
        .init("Houston Astros", "MLB", false, [0x002D62, 0xEB6E1F]),
        .init("Kansas City Royals", "MLB", false, [0x004687, 0xC09A5B]),
        .init("Los Angeles Angels of Anaheim", "MLB", false, [0xBA0021, 0x003263]),
        .init("Los Angeles Dodgers", "MLB", false, [0xEF3E42, 0x005A9C]),
        .init("Miami Marlins", "MLB", false, [0xFF6600, 0x0077C8]),
        .init("Milwaukee Brewers", "MLB", false, [0x0A2351, 0xB6922E]),
        .init("Minnesota Twins", "MLB", false, [0x002B5C, 0xD31145]),
        .init("New York Mets", "MLB", false, [0xFF5910, 0x002D72]),
        .init("New York Yankees", "MLB", false, [0xE4002B, 0x003087]),
        .init("Oakland Athletics", "MLB", false, [0x003831, 0xEFB21E]),
        .init("Philadelphia Phillies", "MLB", false, [0x284898, 0xE81828]),
        .init("Pittsburgh Pirates", "MLB", false, [0xFDB827, 0x000000]),
        .init("San Diego Padres", "MLB", false, [0x002D62, 0xFEC325]),
        .init("San Francisco Giants", "MLB", false, [0xFD5A1E, 0x000000]),
        .init("Seattle Mariners", "MLB", false, [0x0C2C56, 0x005C5C]),
        .init("St Louis Cardinals", "MLB", false, [0xC41E3A, 0x000066]),
        .init("Tampa Bay Rays", "MLB", false, [0x092C5C, 0x8FBCE6]),
        .init("Texas Rangers", "MLB", false, [0xC0111F, 0x003278]),
        .init("Toronto Blue Jays", "MLB", false, [0x134A8E, 0x1D2D5C]),
        .init("Washington Nationals", "MLB", false, [0xAB0003, 0x11225B]),
        .init("Atlanta United FC", "MLS", false, [0xA29061, 0x80000B]),
        .init("Austin FC", "MLS", false, [0x00B140, 0x000000]),
        .init("CF Montréal", "MLS", false, [0x122089, 0x000000]),
        .init("Charlotte FC", "MLS", false, [0x1A85C8, 0x000000]),
        .init("Chicago Fire", "MLS", false, [0xAF2626, 0x0A174A]),
        .init("Colorado Rapids", "MLS", false, [0x91022D, 0x85B7EA]),
        .init("Columbus Crew", "MLS", false, [0x000000, 0xFFDB00]),
        .init("D.C. United", "MLS", false, [0x000000, 0xDD0000]),
        .init("FC Cincinnati", "MLS", false, [0xF05323, 0x263B80]),
        .init("FC Dallas", "MLS", false, [0xCF0032, 0x07175C]),
        .init("Houston Dynamo", "MLS", false, [0xF36600, 0x2E2926]),
        .init("Inter Miami CF", "MLS", false, [0xF7B5CD, 0x231F20]),
        .init("LA Galaxy", "MLS", false, [0x00245D, 0x004689]),
        .init("LAFC", "MLS", false, [0x000000, 0xC39E6D]),
        .init("Minnesota United FC", "MLS", false, [0xCFD4D8, 0x6CADDF]),
        .init("Nashville SC", "MLS", false, [0xECE83A, 0x1F1646]),
        .init("New England Revolution", "MLS", false, [0x0A2141, 0xD80016]),
        .init("New York City FC", "MLS", false, [0x6CADDF, 0x00285E]),
        .init("New York Red Bulls", "MLS", false, [0xD50031, 0x012055]),
        .init("Orlando City SC", "MLS", false, [0x633492, 0xFDE192]),
        .init("Philadelphia Union", "MLS", false, [0x002D55, 0x5090CD]),
        .init("Portland Timbers", "MLS", false, [0x004812, 0xEBE72B]),
        .init("Real Salt Lake", "MLS", false, [0xA50531, 0x013474]),
        .init("San Diego FC", "MLS", false, [0x0B1F3A, 0xB6975C]),
        .init("San Jose Earthquakes", "MLS", false, [0x0051BA, 0x000000]),
        .init("Seattle Sounders FC", "MLS", false, [0x4F8A10, 0x11568C]),
        .init("Sporting Kansas City", "MLS", false, [0x91B0D5, 0x002B5C]),
        .init("St. Louis City SC", "MLS", false, [0xDD004A, 0x0A1E2C]),
        .init("Toronto FC", "MLS", false, [0xD80016, 0x313F49]),
        .init("Vancouver Whitecaps FC", "MLS", false, [0x12264C, 0x85B7EA]),
        .init("Arizona Cardinals", "NFL", false, [0x97233F, 0x000000]),
        .init("Atlanta Falcons", "NFL", false, [0xA71930, 0x000000]),
        .init("Baltimore Ravens", "NFL", false, [0x241773, 0x000000]),
        .init("Buffalo Bills", "NFL", false, [0x00338D, 0xC60C30]),
        .init("Carolina Panthers", "NFL", false, [0x0085CA, 0x000000]),
        .init("Chicago Bears", "NFL", false, [0x0B162A, 0xC83803]),
        .init("Cincinnati Bengals", "NFL", false, [0x000000, 0xFB4F14]),
        .init("Cleveland Browns", "NFL", false, [0xFB4F14, 0x22150C]),
        .init("Dallas Cowboys", "NFL", false, [0x002244, 0xB0B7BC]),
        .init("Denver Broncos", "NFL", false, [0x002244, 0xFB4F14]),
        .init("Detroit Lions", "NFL", false, [0x005A8B, 0xB0B7BC]),
        .init("Green Bay Packers", "NFL", false, [0x203731, 0xFFB612]),
        .init("Houston Texans", "NFL", false, [0x03202F, 0xA71930]),
        .init("Indianapolis Colts", "NFL", false, [0x002C5F, 0xA5ACAF]),
        .init("Jacksonville Jaguars", "NFL", false, [0x000000, 0x006778]),
        .init("Kansas City Chiefs", "NFL", false, [0xE31837, 0xFFB612]),
        .init("Los Angeles Chargers", "NFL", false, [0x002244, 0x0073CF]),
        .init("Los Angeles Rams", "NFL", false, [0x002244, 0xB3995D]),
        .init("Miami Dolphins", "NFL", false, [0x008E97, 0xF58220]),
        .init("Minnesota Vikings", "NFL", false, [0x4F2683, 0xFFC62F]),
        .init("New England Patriots", "NFL", false, [0x002244, 0xC60C30]),
        .init("New Orleans Saints", "NFL", false, [0x9F8958, 0x000000]),
        .init("New York Giants", "NFL", false, [0x0B2265, 0xA71930]),
        .init("New York Jets", "NFL", false, [0x203731]),
        .init("Oakland Raiders", "NFL", false, [0xA5ACAF, 0x000000]),
        .init("Philadelphia Eagles", "NFL", false, [0x004953, 0xA5ACAF]),
        .init("Pittsburgh Steelers", "NFL", false, [0x000000, 0xFFB612]),
        .init("San Francisco 49ers", "NFL", false, [0xAA0000, 0xB3995D]),
        .init("Seattle Seahawks", "NFL", false, [0x002244, 0x69BE28]),
        .init("Tampa Bay Buccaneers", "NFL", false, [0xD50A0A, 0x34302B]),
        .init("Tennessee Titans", "NFL", false, [0x002244, 0x4B92DB]),
        .init("Washington Commanders", "NFL", false, [0x773141, 0xFFB612]),
        .init("Anaheim Ducks", "NHL", false, [0x010101, 0xA2AAAD]),
        .init("Boston Bruins", "NHL", false, [0x010101, 0xFFB81C]),
        .init("Buffalo Sabres", "NHL", false, [0x041E42, 0xA2AAAD]),
        .init("Calgary Flames", "NHL", false, [0x010101, 0xF1BE48]),
        .init("Carolina Hurricanes", "NHL", false, [0x010101, 0xA2AAAD]),
        .init("Chicago Blackhawks", "NHL", false, [0x010101, 0xFF671F]),
        .init("Colorado Avalanche", "NHL", false, [0x010101, 0x236192]),
        .init("Columbus Blue Jackets", "NHL", false, [0x041E42, 0xA4A9AD]),
        .init("Dallas Stars", "NHL", false, [0x010101, 0x006341]),
        .init("Detroit Red Wings", "NHL", false, [0xC8102E]),
        .init("Edmonton Oilers", "NHL", false, [0x00205B, 0xCF4520]),
        .init("Florida Panthers", "NHL", false, [0x041E42, 0xB9975B]),
        .init("Los Angeles Kings", "NHL", false, [0x010101, 0xA2AAAD]),
        .init("Minnesota Wild", "NHL", false, [0x154734, 0xDDCBA4]),
        .init("Montreal Canadiens", "NHL", false, [0x001E62, 0xA6192E]),
        .init("Nashville Predators", "NHL", false, [0x041E42, 0xFFB81C]),
        .init("New Jersey Devils", "NHL", false, [0x010101, 0xC8102E]),
        .init("New York Islanders", "NHL", false, [0x003087, 0xFC4C02]),
        .init("New York Rangers", "NHL", false, [0x0033A0, 0xC8102E]),
        .init("Ottawa Senators", "NHL", false, [0x010101, 0xC8102E]),
        .init("Philadelphia Flyers", "NHL", false, [0x010101, 0xFA4616]),
        .init("Pittsburgh Penguins", "NHL", false, [0x010101, 0xFFB81C]),
        .init("San Jose Sharks", "NHL", false, [0x010101, 0xE57200]),
        .init("Seattle Kraken", "NHL", false, [0x001628, 0x99D9D9]),
        .init("St. Louis Blues", "NHL", false, [0x041E42, 0xFFB81C]),
        .init("Tampa Bay Lightning", "NHL", false, [0x00205B]),
        .init("Toronto Maple Leafs", "NHL", false, [0x00205B]),
        .init("Utah Mammoth", "NHL", false, [0x6CACE4, 0x010101]),
        .init("Vancouver Canucks", "NHL", false, [0x00205B, 0x97999B]),
        .init("Vegas Golden Knights", "NHL", false, [0x010101, 0xB4975A]),
        .init("Washington Capitals", "NHL", false, [0x041E42, 0xA2AAAD]),
        .init("Winnipeg Jets", "NHL", false, [0x041E42, 0xC8102E]),
        .init("Angel City FC", "NWSL", true, [0x000000, 0xF0A6B7]),
        .init("Bay FC", "NWSL", true, [0x0B2240, 0xEF4B3E]),
        .init("Boston Legacy FC", "NWSL", true, [0x0B5D3B, 0xF2E8D0]),
        .init("Chicago Stars FC", "NWSL", true, [0x41B6E6, 0xC8102E]),
        .init("Denver Summit FC", "NWSL", true, [0x1B3C6E, 0xE4B363]),
        .init("Gotham FC", "NWSL", true, [0x000000, 0x9DD7C9]),
        .init("Houston Dash", "NWSL", true, [0xF68712, 0x8ABBEA]),
        .init("Kansas City Current", "NWSL", true, [0x62CBC9, 0xCF3339]),
        .init("North Carolina Courage", "NWSL", true, [0x00245D, 0xC5A03F]),
        .init("Orlando Pride", "NWSL", true, [0x633492, 0x61B3E4]),
        .init("Portland Thorns FC", "NWSL", true, [0x971D1F, 0x000000]),
        .init("Racing Louisville FC", "NWSL", true, [0xC5B3E0, 0x1B1F3B]),
        .init("San Diego Wave FC", "NWSL", true, [0x012A5C, 0xF26B21]),
        .init("Seattle Reign FC", "NWSL", true, [0x1B2A4A, 0xC6A45B]),
        .init("Utah Royals FC", "NWSL", true, [0xFDB71A, 0x1F2F6B]),
        .init("Washington Spirit", "NWSL", true, [0x000000, 0xD10A11]),
        .init("Boston Fleet", "PWHL", true, [0x1F5E45, 0xD9C58B]),
        .init("Minnesota Frost", "PWHL", true, [0x262161, 0xA7A9AC]),
        .init("Montréal Victoire", "PWHL", true, [0x8E1537, 0xF2C4A0]),
        .init("New York Sirens", "PWHL", true, [0x0E7C7B, 0x1C2B39]),
        .init("Ottawa Charge", "PWHL", true, [0xC8102E, 0x1A1A1A]),
        .init("Seattle Torrent", "PWHL", true, [0x0A4D5C, 0x7FD1C8]),
        .init("Toronto Sceptres", "PWHL", true, [0x0067B9, 0xB9975B]),
        .init("Vancouver Goldeneyes", "PWHL", true, [0xE0A526, 0x0B2545]),
        .init("Atlanta Dream", "WNBA", true, [0xC8102E, 0x418FDE]),
        .init("Chicago Sky", "WNBA", true, [0x418FDE, 0xFFCD00]),
        .init("Connecticut Sun", "WNBA", true, [0xF05023, 0x0A2240]),
        .init("Dallas Wings", "WNBA", true, [0x002B5C, 0xC4D600]),
        .init("Golden State Valkyries", "WNBA", true, [0x5B2B82, 0x000000]),
        .init("Indiana Fever", "WNBA", true, [0x002D62, 0xE03A3E]),
        .init("Las Vegas Aces", "WNBA", true, [0x000000, 0xBA0C2F]),
        .init("Los Angeles Sparks", "WNBA", true, [0x552583, 0xFDB927]),
        .init("Minnesota Lynx", "WNBA", true, [0x0C2340, 0x78BE20]),
        .init("New York Liberty", "WNBA", true, [0x6ECEB2, 0x000000]),
        .init("Phoenix Mercury", "WNBA", true, [0x201747, 0xE56020]),
        .init("Portland Fire", "WNBA", true, [0xCE1141, 0x000000]),
        .init("Seattle Storm", "WNBA", true, [0x2C5235, 0xFEE11A]),
        .init("Toronto Tempo", "WNBA", true, [0x6B1F3A, 0xB9D9EB]),
        .init("Washington Mystics", "WNBA", true, [0x002B5C, 0xE03A3E]),
    ]

    /// Teams whose names fit what the ticket says, best first.
    static func find(_ name: String) -> [Entry] {
        all.map { ($0, Teams.fit(name, $0.name)) }.filter { $0.1 >= 5 }.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// Both sides, from the same gender: the women's team when the ticket says so or when
    /// both names fit women's teams (the Liberty, not the Flames).
    static func matchup(_ a: String, _ b: String, context: String) -> (Entry?, Entry?) {
        let la = find(a), lb = find(b)
        var women = Teams.isWomens(context)
        if !women, la.contains(where: \.female), lb.contains(where: \.female),
           !(la.contains { !$0.female } && lb.contains { !$0.female }) { women = true }
        func pick(_ l: [Entry], other: [Entry]) -> Entry? {
            let g = l.filter { $0.female == women }
            let pool = g.isEmpty ? l : g
            // Same league as the other side when there's a choice.
            if let o = other.first(where: { $0.female == women }), let same = pool.first(where: { $0.league == o.league }) { return same }
            return pool.first
        }
        return (pick(la, other: lb), pick(lb, other: la))
    }
}

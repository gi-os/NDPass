import WidgetKit
import SwiftUI

struct NextShowing: Codable {
    let movieTitle: String
    let theater: String
    let date: String
    let time: String
    let posterUrl: String?
    let dominantColor: String?
}

struct NextShowingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextShowingEntry {
        NextShowingEntry(date: Date(), showing: NextShowing(
            movieTitle: "Three Colors: Red", theater: "Metrograph",
            date: "2026-04-30", time: "7:30 PM", posterUrl: nil, dominantColor: "#E8A63A"
        ), posterImage: nil, relevance: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextShowingEntry) -> Void) {
        let (s, img) = loadData()
        completion(NextShowingEntry(date: Date(), showing: s, posterImage: img, relevance: nil))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextShowingEntry>) -> Void) {
        let (showing, img) = loadData()
        var entries = [NextShowingEntry(date: Date(), showing: showing, posterImage: img, relevance: nil)]
        if let s = showing {
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd h:mm a"
            if let st = fmt.date(from: "\(s.date) \(s.time)") {
                for (mins, score): (Int, Float) in [(-180, 50), (-60, 100), (-30, 100)] {
                    let t = st.addingTimeInterval(TimeInterval(mins * 60))
                    if t > Date() { entries.append(NextShowingEntry(date: t, showing: s, posterImage: img, relevance: TimelineEntryRelevance(score: score))) }
                }
            }
        }
        completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(1800))))
    }
    private func loadData() -> (NextShowing?, UIImage?) {
        guard let d = UserDefaults(suiteName: "group.com.gios.ndpass") else { return (nil, nil) }
        var showing: NextShowing? = nil
        if let str = d.string(forKey: "nextShowing"), !str.isEmpty, let data = str.data(using: .utf8) {
            showing = try? JSONDecoder().decode(NextShowing.self, from: data)
        }
        var image: UIImage? = nil
        if let b64 = d.string(forKey: "widgetPosterBase64"), !b64.isEmpty, let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) {
            image = UIImage(data: data)
        }
        return (showing, image)
    }
}

struct NextShowingEntry: TimelineEntry {
    let date: Date; let showing: NextShowing?; let posterImage: UIImage?; let relevance: TimelineEntryRelevance?
}

func daysUntil(_ dateStr: String) -> String {
    let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
    guard let target = fmt.date(from: dateStr) else { return dateStr }
    let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: target)).day ?? 0
    if diff == 0 { return "Today" }; if diff == 1 { return "Tomorrow" }; if diff < 0 { return "Past" }
    return "In \(diff) days"
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var n: UInt64 = 0; Scanner(string: h).scanHexInt64(&n)
        self.init(red: Double((n >> 16) & 0xFF) / 255, green: Double((n >> 8) & 0xFF) / 255, blue: Double(n & 0xFF) / 255)
    }
}

let darkBg = Color(red: 0.03, green: 0.03, blue: 0.05)

struct PosterImage: View {
    let uiImage: UIImage
    var body: some View { Image(uiImage: uiImage).renderingMode(.original).resizable() }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: NextShowingEntry
    let accent: Color
    
    var body: some View {
        if let showing = entry.showing {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Two columns: poster + time info
                    HStack(spacing: 6) {
                        // Poster — 45% width, fills height
                        Group {
                            if let img = entry.posterImage {
                                PosterImage(uiImage: img).aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.white.opacity(0.06))
                                    .overlay { Image(systemName: "film").font(.system(size: 16)).foregroundStyle(.white.opacity(0.15)) }
                            }
                        }
                        .frame(width: geo.size.width * 0.45, height: geo.size.height * 0.72)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Time info only
                        VStack(alignment: .leading, spacing: 6) {
                            Spacer(minLength: 0)
                            
                            Text(daysUntil(showing.date))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                            
                            Text(showing.time)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                            
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                    
                    Spacer(minLength: 0)
                    
                    // Title at bottom
                    Text(showing.movieTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                }
            }
            .containerBackground(for: .widget) { darkBg }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "ticket").font(.system(size: 22)).foregroundStyle(.white.opacity(0.2))
                Text("No shows").font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
            }
            .containerBackground(for: .widget) { darkBg }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: NextShowingEntry
    let accent: Color
    
    var body: some View {
        if let showing = entry.showing {
            HStack(spacing: 14) {
                Group {
                    if let img = entry.posterImage {
                        PosterImage(uiImage: img).aspectRatio(2/3, contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.white.opacity(0.06))
                            .overlay { Image(systemName: "film").foregroundStyle(.white.opacity(0.15)) }
                    }
                }
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(showing.movieTitle).font(.system(size: 16, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                    Text(showing.theater).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(accent).lineLimit(1)
                    Spacer(minLength: 2)
                    Text(daysUntil(showing.date)).font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.5))
                    Text(showing.time).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .containerBackground(for: .widget) { darkBg }
        } else {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "ticket").font(.system(size: 24)).foregroundStyle(.white.opacity(0.2))
                    Text("No upcoming shows").font(.system(size: 11, design: .monospaced)).foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            }
            .containerBackground(for: .widget) { darkBg }
        }
    }
}

@main
struct NextShowingWidget: Widget {
    let kind = "NextShowingWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextShowingProvider()) { entry in
            WidgetRouter(entry: entry)
        }
        .configurationDisplayName("Next Showing")
        .description("Your next movie at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetRouter: View {
    @Environment(\.widgetFamily) var family
    let entry: NextShowingEntry
    var accent: Color { Color(hex: entry.showing?.dominantColor ?? "#E8A63A") }
    var body: some View {
        switch family {
        case .systemSmall: SmallWidgetView(entry: entry, accent: accent)
        default: MediumWidgetView(entry: entry, accent: accent)
        }
    }
}

import WidgetKit
import SwiftUI

// MARK: - Data Model

struct NextShowing: Codable {
    let movieTitle: String
    let theater: String
    let date: String
    let time: String
    let posterUrl: String?
    let dominantColor: String?
}

// MARK: - Provider

struct NextShowingProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextShowingEntry {
        NextShowingEntry(date: Date(), showing: NextShowing(
            movieTitle: "Three Colors: Red", theater: "Metrograph",
            date: "2026-04-30", time: "7:30 PM", posterUrl: nil, dominantColor: "#E8A63A"
        ), posterImage: nil, relevance: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NextShowingEntry) -> Void) {
        let (showing, image) = loadData()
        completion(NextShowingEntry(date: Date(), showing: showing, posterImage: image, relevance: nil))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextShowingEntry>) -> Void) {
        let (showing, image) = loadData()
        var entries: [NextShowingEntry] = []
        entries.append(NextShowingEntry(date: Date(), showing: showing, posterImage: image, relevance: nil))
        
        if let showing = showing {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd h:mm a"
            if let showtime = fmt.date(from: "\(showing.date) \(showing.time)") {
                for (offset, score): (Int, Float) in [(-180, 50), (-60, 100), (-30, 100)] {
                    let t = showtime.addingTimeInterval(TimeInterval(offset * 60))
                    if t > Date() {
                        entries.append(NextShowingEntry(date: t, showing: showing, posterImage: image, relevance: TimelineEntryRelevance(score: score)))
                    }
                }
            }
        }
        
        let next = Date().addingTimeInterval(1800)
        completion(Timeline(entries: entries, policy: .after(next)))
    }
    
    private func loadData() -> (NextShowing?, UIImage?) {
        guard let defaults = UserDefaults(suiteName: "group.com.gios.ndpass") else { return (nil, nil) }
        
        var showing: NextShowing? = nil
        if let s = defaults.string(forKey: "nextShowing"), let d = s.data(using: .utf8) {
            showing = try? JSONDecoder().decode(NextShowing.self, from: d)
        }
        
        // Load poster — try App Group file first, then UserDefaults base64
        var image: UIImage? = nil
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.gios.ndpass") {
            let posterFile = containerURL.appendingPathComponent("widget_poster.jpg")
            if let data = try? Data(contentsOf: posterFile) {
                image = UIImage(data: data)
            }
        }
        // Fallback: read base64 from UserDefaults
        if image == nil, let b64String = defaults.string(forKey: "widgetPosterBase64"),
           let data = Data(base64Encoded: b64String) {
            image = UIImage(data: data)
        }
        
        return (showing, image)
    }
}

// MARK: - Entry

struct NextShowingEntry: TimelineEntry {
    let date: Date
    let showing: NextShowing?
    let posterImage: UIImage?
    let relevance: TimelineEntryRelevance?
}

// MARK: - Helper

func daysUntil(_ dateStr: String) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    guard let target = fmt.date(from: dateStr) else { return dateStr }
    let cal = Calendar.current
    let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: target)).day ?? 0
    if diff == 0 { return "Today" }
    if diff == 1 { return "Tomorrow" }
    if diff < 0 { return "Past" }
    return "In \(diff) days"
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: NextShowingEntry
    let accent: Color
    
    var body: some View {
        if let showing = entry.showing {
            VStack(spacing: 0) {
                // Poster top half
                if let img = entry.posterImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 90)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 90)
                        .overlay {
                            Image(systemName: "film")
                                .font(.system(size: 20))
                                .foregroundStyle(.white.opacity(0.2))
                        }
                }
                
                // Info bottom half
                VStack(alignment: .leading, spacing: 3) {
                    Text(showing.movieTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    
                    Text(daysUntil(showing.date))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accent)
                    
                    Text(showing.time)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.05)
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "ticket")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.2))
                Text("No shows")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.05)
            }
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
                // Poster
                if let img = entry.posterImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 85, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 85, height: 120)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.white.opacity(0.2))
                        }
                }
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(showing.movieTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    Text(showing.theater)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                    
                    Spacer(minLength: 2)
                    
                    Text(daysUntil(showing.date))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                    
                    Text(showing.time)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer(minLength: 0)
            }
            .padding(14)
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.05)
            }
        } else {
            HStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "ticket")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.2))
                    Text("No upcoming shows")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            }
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.05)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red: Double((int >> 16) & 0xFF) / 255.0,
            green: Double((int >> 8) & 0xFF) / 255.0,
            blue: Double(int & 0xFF) / 255.0
        )
    }
}

// MARK: - Widget

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
    
    var accent: Color {
        Color(hex: entry.showing?.dominantColor ?? "#E8A63A")
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry, accent: accent)
        default:
            MediumWidgetView(entry: entry, accent: accent)
        }
    }
}

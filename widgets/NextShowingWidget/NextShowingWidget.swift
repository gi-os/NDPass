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

// MARK: - Timeline Provider

struct NextShowingProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> NextShowingEntry {
        NextShowingEntry(
            date: Date(),
            showing: NextShowing(
                movieTitle: "Three Colors: Red",
                theater: "Metrograph",
                date: "2026-04-30",
                time: "7:30 PM",
                posterUrl: nil,
                dominantColor: "#E8A63A"
            ),
            relevance: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (NextShowingEntry) -> Void) {
        completion(NextShowingEntry(date: Date(), showing: loadNextShowing(), relevance: nil))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextShowingEntry>) -> Void) {
        let showing = loadNextShowing()
        var entries: [NextShowingEntry] = []
        entries.append(NextShowingEntry(date: Date(), showing: showing, relevance: nil))
        
        if let showing = showing {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd h:mm a"
            if let showtime = formatter.date(from: "\(showing.date) \(showing.time)") {
                let threeHrs = Calendar.current.date(byAdding: .hour, value: -3, to: showtime)!
                if threeHrs > Date() {
                    entries.append(NextShowingEntry(date: threeHrs, showing: showing, relevance: TimelineEntryRelevance(score: 50)))
                }
                let oneHr = Calendar.current.date(byAdding: .hour, value: -1, to: showtime)!
                if oneHr > Date() {
                    entries.append(NextShowingEntry(date: oneHr, showing: showing, relevance: TimelineEntryRelevance(score: 100)))
                }
            }
        }
        
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: entries, policy: .after(next)))
    }
    
    private func loadNextShowing() -> NextShowing? {
        guard let defaults = UserDefaults(suiteName: "group.com.gios.ndpass") else { return nil }
        
        if let jsonString = defaults.string(forKey: "nextShowing"),
           let data = jsonString.data(using: .utf8),
           let showing = try? JSONDecoder().decode(NextShowing.self, from: data) {
            return showing
        }
        if let data = defaults.data(forKey: "nextShowing"),
           let showing = try? JSONDecoder().decode(NextShowing.self, from: data) {
            return showing
        }
        return nil
    }
}

// MARK: - Entry

struct NextShowingEntry: TimelineEntry {
    let date: Date
    let showing: NextShowing?
    let relevance: TimelineEntryRelevance?
}

// MARK: - Helper

func daysUntil(_ dateStr: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let target = formatter.date(from: dateStr) else { return dateStr }
    
    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let targetDay = cal.startOfDay(for: target)
    let diff = cal.dateComponents([.day], from: today, to: targetDay).day ?? 0
    
    if diff == 0 { return "Today" }
    if diff == 1 { return "Tomorrow" }
    if diff < 0 { return "Past" }
    return "\(diff) days away"
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: NextShowingEntry
    
    var body: some View {
        if let showing = entry.showing {
            ZStack {
                // Poster as full background
                if let posterUrl = showing.posterUrl, let url = URL(string: posterUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color(red: 0.05, green: 0.05, blue: 0.08)
                        }
                    }
                } else {
                    Color(red: 0.05, green: 0.05, blue: 0.08)
                }
                
                // Bottom gradient with info
                VStack {
                    Spacer()
                    LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 70)
                }
                
                // Text at bottom
                VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text(daysUntil(showing.date))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: showing.dominantColor ?? "#E8A63A"))
                        Text(showing.time)
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            .containerBackground(for: .widget) { Color.clear }
        } else {
            emptyView
        }
    }
    
    var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "ticket")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.25))
            Text("No shows")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
        }
        .containerBackground(for: .widget) {
            Color(red: 0.05, green: 0.05, blue: 0.08)
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: NextShowingEntry
    
    var body: some View {
        if let showing = entry.showing {
            HStack(spacing: 14) {
                // Poster
                if let posterUrl = showing.posterUrl, let url = URL(string: posterUrl) {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 90, height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            posterPlaceholder
                        }
                    }
                } else {
                    posterPlaceholder
                }
                
                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(showing.movieTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    Text(showing.theater)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: showing.dominantColor ?? "#E8A63A"))
                        .lineLimit(1)
                    
                    Spacer(minLength: 4)
                    
                    Text(daysUntil(showing.date))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Text(showing.time)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
                
                Spacer(minLength: 0)
            }
            .padding(14)
            .containerBackground(for: .widget) {
                Color(red: 0.05, green: 0.05, blue: 0.08)
            }
        } else {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "ticket")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.25))
                    Text("No upcoming shows")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
            }
            .containerBackground(for: .widget) {
                Color(red: 0.05, green: 0.05, blue: 0.08)
            }
        }
    }
    
    var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.white.opacity(0.06))
            .frame(width: 90, height: 130)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.white.opacity(0.2))
            }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget

@main
struct NextShowingWidget: Widget {
    let kind: String = "NextShowingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextShowingProvider()) { entry in
            switch WidgetFamily(rawValue: entry.date.hashValue) {
            default:
                if #available(iOSApplicationExtension 16.0, *) {
                    // Use environment to detect family
                    WidgetView(entry: entry)
                } else {
                    MediumWidgetView(entry: entry)
                }
            }
        }
        .configurationDisplayName("Next Showing")
        .description("Your next movie at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: NextShowingEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

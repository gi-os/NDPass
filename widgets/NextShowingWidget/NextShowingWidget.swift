import WidgetKit
import SwiftUI

// MARK: - Data Model

struct NextShowing: Codable {
    let movieTitle: String
    let theater: String
    let date: String        // YYYY-MM-DD
    let time: String        // h:mm AM/PM
    let posterUrl: String?
    let dominantColor: String? // hex color from poster
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
        let entry = NextShowingEntry(date: Date(), showing: loadNextShowing(), relevance: nil)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextShowingEntry>) -> Void) {
        let showing = loadNextShowing()
        var entries: [NextShowingEntry] = []
        
        // Current entry
        entries.append(NextShowingEntry(date: Date(), showing: showing, relevance: nil))
        
        // If there's an upcoming showing, create high-relevance entries
        // starting 3 hours before showtime so Smart Stack surfaces the widget
        if let showing = showing {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd h:mm a"
            if let showtime = formatter.date(from: "\(showing.date) \(showing.time)") {
                // 3 hours before — medium relevance
                let threeHrsBefore = Calendar.current.date(byAdding: .hour, value: -3, to: showtime)!
                if threeHrsBefore > Date() {
                    entries.append(NextShowingEntry(
                        date: threeHrsBefore,
                        showing: showing,
                        relevance: TimelineEntryRelevance(score: 50)
                    ))
                }
                
                // 1 hour before — high relevance
                let oneHrBefore = Calendar.current.date(byAdding: .hour, value: -1, to: showtime)!
                if oneHrBefore > Date() {
                    entries.append(NextShowingEntry(
                        date: oneHrBefore,
                        showing: showing,
                        relevance: TimelineEntryRelevance(score: 100)
                    ))
                }
                
                // 30 min before — max relevance
                let thirtyMinBefore = Calendar.current.date(byAdding: .minute, value: -30, to: showtime)!
                if thirtyMinBefore > Date() {
                    entries.append(NextShowingEntry(
                        date: thirtyMinBefore,
                        showing: showing,
                        relevance: TimelineEntryRelevance(score: 100)
                    ))
                }
            }
        }
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }
    
    /// Read next showing from shared App Group UserDefaults
    private func loadNextShowing() -> NextShowing? {
        guard let defaults = UserDefaults(suiteName: "group.com.gios.ndpass"),
              let data = defaults.data(forKey: "nextShowing"),
              let showing = try? JSONDecoder().decode(NextShowing.self, from: data)
        else { return nil }
        return showing
    }
}

// MARK: - Timeline Entry

struct NextShowingEntry: TimelineEntry {
    let date: Date
    let showing: NextShowing?
    let relevance: TimelineEntryRelevance?
}

// MARK: - Widget View

struct NextShowingWidgetView: View {
    var entry: NextShowingEntry
    @Environment(\.widgetFamily) var family
    
    var accentColor: Color {
        if let hex = entry.showing?.dominantColor {
            return Color(hex: hex)
        }
        return Color(red: 0.91, green: 0.65, blue: 0.23) // default amber
    }
    
    var body: some View {
        if let showing = entry.showing {
            ZStack {
                // Color-matched background
                LinearGradient(
                    colors: [
                        accentColor.opacity(0.3),
                        Color(red: 0.03, green: 0.03, blue: 0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                HStack(spacing: 12) {
                    // Poster
                    if let posterUrl = showing.posterUrl, let url = URL(string: posterUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: family == .systemSmall ? 50 : 60,
                                           height: family == .systemSmall ? 75 : 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            default:
                                posterPlaceholder
                            }
                        }
                    } else {
                        posterPlaceholder
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showing.movieTitle)
                            .font(.system(size: family == .systemSmall ? 14 : 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        
                        Text(showing.theater)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(accentColor)
                            .lineLimit(1)
                        
                        Spacer(minLength: 2)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(formatDate(showing.date))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(showing.time)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.06)
            }
        } else {
            // Empty state
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.06)
                VStack(spacing: 8) {
                    Image(systemName: "ticket")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No upcoming shows")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .containerBackground(for: .widget) {
                Color(red: 0.03, green: 0.03, blue: 0.06)
            }
        }
    }
    
    var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.06))
            .frame(width: family == .systemSmall ? 50 : 60,
                   height: family == .systemSmall ? 75 : 90)
            .overlay {
                Image(systemName: "film")
                    .foregroundStyle(.white.opacity(0.2))
            }
    }
    
    func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateStr) else { return dateStr }
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Color hex init

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

// MARK: - Widget Definition

@main
struct NextShowingWidget: Widget {
    let kind: String = "NextShowingWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextShowingProvider()) { entry in
            NextShowingWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Showing")
        .description("Your next movie ticket at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

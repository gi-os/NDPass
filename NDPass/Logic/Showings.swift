import Foundation

/// Groups of tickets for the same showing, upcoming first by showtime or past newest first.
/// A showing is upcoming or past as a whole (decided by its first ticket), so a group never
/// splits between the two lists.
enum Showings {
    static func groups(_ passes: [Pass], archived: Bool?) -> [[Pass]] {
        let all = Dictionary(grouping: passes, by: \.group).values.map { sortSeats($0) }
        let filtered = archived.map { a in all.filter { $0[0].isArchived == a } } ?? all
        let upcoming = archived == false
        return filtered.sorted { a, b in upcoming ? a[0].listDate < b[0].listDate : a[0].listDate > b[0].listDate }
    }

    /// Seats in the order they're printed: F9 before F10.
    static func sortSeats(_ g: [Pass]) -> [Pass] {
        g.sorted { $0.seat.localizedStandardCompare($1.seat) == .orderedAscending }
    }

    static func seats(_ g: [Pass]) -> String { g.map(\.seat).filter { !$0.isEmpty }.joined(separator: " ") }
}

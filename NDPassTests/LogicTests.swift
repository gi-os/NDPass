import XCTest
import SwiftData
@testable import NDPass

final class TicketDateTests: XCTestCase {
    var cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/New_York")!; return c }()
    func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    func testYearlessDateIsUpcoming() {
        XCTAssertEqual(TicketDate.resolveFromModel("12-18", today: day(2026, 9, 28), calendar: cal), "2026-12-18")
        XCTAssertEqual(TicketDate.resolveFromModel("03-02", today: day(2026, 9, 28), calendar: cal), "2027-03-02")
    }

    func testIsoYearlessSpelling() {
        XCTAssertEqual(TicketDate.resolveFromModel("--12-18", today: day(2026, 9, 28), calendar: cal), "2026-12-18")
    }

    func testGraceWindowKeepsLastNight() {
        XCTAssertEqual(TicketDate.resolveFromModel("09-27", today: day(2026, 9, 28), calendar: cal), "2026-09-27")
        XCTAssertEqual(TicketDate.resolveFromModel("09-20", today: day(2026, 9, 28), calendar: cal), "2027-09-20")
    }

    func testInventedYearIsIgnored() {
        // A printed year is kept: old stubs keep their own year…
        XCTAssertEqual(TicketDate.resolveFromModel("2024-12-18", today: day(2026, 9, 28), calendar: cal), "2024-12-18")
        XCTAssertEqual(TicketDate.resolveFromModel("2019-05-04", evidence: "FILM FORUM 05/04/2019 7:00PM", today: day(2026, 9, 28), calendar: cal), "2019-05-04")
        // …unless the ticket's own text doesn't have it (the model made it up)…
        XCTAssertEqual(TicketDate.resolveFromModel("2024-12-18", evidence: "DEC 18 7:30PM SEAT F12", today: day(2026, 9, 28), calendar: cal), "2026-12-18")
        // …or it's years ahead.
        XCTAssertEqual(TicketDate.resolveFromModel("2031-12-18", today: day(2026, 9, 28), calendar: cal), "2026-12-18")
        XCTAssertEqual(TicketDate.resolveFromModel("2025-12-18", today: day(2026, 9, 28), calendar: cal), "2025-12-18")
    }

    func testTypedYearIsKept() {
        XCTAssertEqual(TicketDate.resolveTyped("2019-05-04", today: day(2026, 9, 28), calendar: cal), "2019-05-04")
    }

    func testLeapDayFindsTheNextLeapYear() {
        XCTAssertEqual(TicketDate.resolveFromModel("02-29", today: day(2026, 9, 28), calendar: cal), "2028-02-29")
    }

    func testUnknownShapesAreLeftAlone() {
        XCTAssertEqual(TicketDate.resolveFromModel("Dec 18", today: day(2026, 9, 28), calendar: cal), "Dec 18")
        XCTAssertNil(TicketDate.resolveFromModel("  ", today: day(2026, 9, 28), calendar: cal))
    }
}

final class CodeTests: XCTestCase {
    func testNormalize() {
        XCTAssertEqual(BookingCode.normalize("  ABC 123 XYZ "), "ABC 123 XYZ")
        XCTAssertNil(BookingCode.normalize("n/a"))
        XCTAssertNil(BookingCode.normalize("A1"))
    }

    func testSymbology() {
        XCTAssertEqual(BookingCode.symbology(for: "AB12-CD34"), .code128)
        XCTAssertEqual(BookingCode.symbology(for: "AB 12"), .qr)
        XCTAssertEqual(BookingCode.symbology(for: String(repeating: "A", count: 25)), .qr)
        XCTAssertEqual(BookingCode.symbology(for: String(repeating: "A", count: 60)), .pdf417)
    }

    func testBestPrefersTwoD() {
        let f = [CodeScan.Found(text: "1234567890123", format: .code128), CodeScan.Found(text: "XYZ", format: .qr), CodeScan.Found(text: "12", format: .code128)]
        XCTAssertEqual(CodeScan.best(f)?.format, .qr)
        XCTAssertNil(CodeScan.best([CodeScan.Found(text: "123", format: .code128)]))
    }
}

final class TimesTests: XCTestCase {
    func testMisreadAM() {
        XCTAssertEqual(PassTimes.normalizeTime("1:30 AM"), "1:30 PM")
        XCTAssertEqual(PassTimes.normalizeTime("11:15 a.m."), "11:15 AM")
        XCTAssertEqual(PassTimes.normalizeTime("7:05pm"), "7:05 PM")
        XCTAssertEqual(PassTimes.normalizeTime("19:30"), "7:30 PM")
        XCTAssertEqual(PassTimes.normalizeTime("7:30"), "7:30 PM")
        XCTAssertEqual(PassTimes.normalizeTime("10:45"), "10:45 AM")
        XCTAssertEqual(PassTimes.normalizeTime("0:15"), "12:15 AM")
        XCTAssertEqual(PassTimes.display("KNICKS VS CELTICS"), "Knicks vs Celtics")
        XCTAssertEqual(PassTimes.display("The xx"), "The xx")
    }

    func testHumanDate() {
        XCTAssertEqual(PassTimes.humanDate("2026-08-06"), "August 6th")
        XCTAssertEqual(PassTimes.humanDate("2026-08-01"), "August 1st")
        XCTAssertEqual(PassTimes.humanDate("2026-08-12"), "August 12th")
        XCTAssertEqual(PassTimes.humanDate("2026-08-23"), "August 23rd")
    }

    func testStart() {
        let ny = TimeZone(identifier: "America/New_York")!
        XCTAssertNotNil(PassTimes.start(date: "2026-08-06", time: "7:30 PM", tz: ny))
        XCTAssertNotNil(PassTimes.start(date: "2026-08-06", time: "19:30", tz: ny))
        XCTAssertNil(PassTimes.start(date: "", time: "7:30 PM"))
    }

    func testMatchup() {
        XCTAssertEqual(Matchup.split("Knicks vs Celtics")?.0, "Knicks")
        XCTAssertEqual(Matchup.split("Mets @ Braves")?.1, "Braves")
        XCTAssertNil(Matchup.split("Attack of the Clones"))
    }

    func testTitleCase() {
        XCTAssertEqual(PassTimes.titleCase("REGAL UNION SQUARE"), "Regal Union Square")
        XCTAssertEqual(PassTimes.titleCase("AMC LINCOLN SQUARE 13"), "AMC Lincoln Square 13")
    }
}

final class ParserTests: XCTestCase {
    func testDecodesModelJSON() throws {
        let text = """
        {"kind":"movie","movieTitle":"One Battle After Another","theater":"REGAL UNION SQUARE","date":"2025-10-04","time":"7:30 PM","seat":"F12","price":"$19.50","code":"A1B2C3D4","confidence":0.93,"box":[100,200,900,700]}
        """
        let p = try Parser.decodeText(text)
        XCTAssertEqual(p.title, "One Battle After Another")
        XCTAssertEqual(p.venue, "Regal Union Square")
        XCTAssertEqual(p.seat, "F12")
        XCTAssertEqual(p.code, "A1B2C3D4")
        XCTAssertEqual(p.box!.minX, 0.1, accuracy: 1e-9)
        XCTAssertEqual(p.box!.height, 0.5, accuracy: 1e-9)
    }

    func testNotATicket() throws {
        XCTAssertTrue(try Parser.decodeText(#"{"error":"not_a_ticket","confidence":0}"#).notATicket)
    }

    func testNullsBecomeEmpty() throws {
        let p = try Parser.decodeText(#"{"movieTitle":"X","seat":null,"code":"null"}"#)
        XCTAssertEqual(p.seat, "")
        XCTAssertEqual(p.code, "")
    }
}

final class StubShapeTests: XCTestCase {
    /// The top-left corner used to be skipped: the path closed with a straight line.
    func testAllFourCornersAreRounded() {
        let r = CGRect(x: 0, y: 0, width: 300, height: 200)
        let p = StubShape(corner: 28, notch: 14, at: 0.5).path(in: r)
        XCTAssertFalse(p.contains(CGPoint(x: 2, y: 2)), "top-left corner should be cut round")
        XCTAssertFalse(p.contains(CGPoint(x: 298, y: 2)))
        XCTAssertFalse(p.contains(CGPoint(x: 2, y: 198)))
        XCTAssertFalse(p.contains(CGPoint(x: 298, y: 198)))
        XCTAssertTrue(p.contains(CGPoint(x: 30, y: 10)))
        XCTAssertFalse(p.contains(CGPoint(x: 3, y: 100)), "left notch")
        XCTAssertTrue(p.contains(CGPoint(x: 150, y: 100)))
    }
}

final class OnDeviceReaderTests: XCTestCase {
    func testDates() {
        XCTAssertEqual(OnDeviceReader.date(in: "FRI DEC 18"), "12-18")
        XCTAssertEqual(OnDeviceReader.date(in: "Date: 10/09/2026"), "2026-10-09")
        XCTAssertEqual(OnDeviceReader.date(in: "October 9th, 2026 7:30 PM"), "2026-10-09")
        XCTAssertEqual(OnDeviceReader.date(in: "2026-08-06"), "2026-08-06")
        XCTAssertNil(OnDeviceReader.date(in: "Row F Seat 12"))
    }

    func testPatternsReadAStub() {
        let lines = ["REGAL UNION SQUARE", "ONE BATTLE AFTER ANOTHER", "FRI OCT 9  7:30 PM", "AUD 12  ROW F SEAT 12", "ADULT $19.50", "Booking ref: A1B2C3D4"]
        let p = OnDeviceReader.patterns(lines)
        XCTAssertEqual(p.title, "ONE BATTLE AFTER ANOTHER")
        XCTAssertEqual(p.venue, "REGAL UNION SQUARE")
        XCTAssertEqual(p.time, "7:30 PM")
        XCTAssertEqual(p.price, "$19.50")
        XCTAssertEqual(p.date, "10-09")
        XCTAssertEqual(p.code, "A1B2C3D4")
        XCTAssertTrue(p.seat.contains("SEAT 12"))
    }
}

final class TornStubTests: XCTestCase {
    func testNotchesOnTheTear() {
        let p = TornStubShape(corner: 18, notch: 9, atX: 0.7).path(in: CGRect(x: 0, y: 0, width: 300, height: 150))
        XCTAssertFalse(p.contains(CGPoint(x: 210, y: 3)))
        XCTAssertFalse(p.contains(CGPoint(x: 210, y: 147)))
        XCTAssertTrue(p.contains(CGPoint(x: 210, y: 75)))
        XCTAssertFalse(p.contains(CGPoint(x: 2, y: 2)))
    }
}

final class TeamColorTests: XCTestCase {
    func testWomensShortNames() {
        let (a, b) = TeamColors.matchup("NY Liberty", "Aces", context: "")
        XCTAssertEqual(a?.name, "New York Liberty")
        XCTAssertEqual(b?.name, "Las Vegas Aces")
    }
    func testNWSL() {
        let (a, b) = TeamColors.matchup("Gotham", "Portland Thorns", context: "")
        XCTAssertEqual(a?.league, "NWSL")
        XCTAssertEqual(b?.league, "NWSL")
    }
    func testMen() {
        let (a, b) = TeamColors.matchup("Knicks", "Celtics", context: "")
        XCTAssertEqual(a?.name, "New York Knicks")
        XCTAssertEqual(b?.name, "Boston Celtics")
    }
    func testNoWrongTeams() {
        // Names that only share a word with a team in the list keep their own name.
        XCTAssertNil(TeamColors.matchup("Manchester City", "Arsenal", context: "").0)
        XCTAssertNil(TeamColors.matchup("LSU Tigers", "Alabama", context: "").0)
        XCTAssertNil(TeamColors.matchup("Durham Bulls", "Norfolk Tides", context: "").0)
        XCTAssertNil(TeamColors.matchup("Oregon Ducks", "USC Trojans", context: "").0)
        XCTAssertEqual(TeamColors.matchup("DC United", "NY Red Bulls", context: "").0?.name, "D.C. United")
        XCTAssertEqual(TeamColors.matchup("DC United", "NY Red Bulls", context: "").1?.name, "New York Red Bulls")
        // The other side's league settles a shared nickname.
        XCTAssertEqual(TeamColors.matchup("Kings", "Ducks", context: "").0?.name, "Los Angeles Kings")
        XCTAssertEqual(TeamColors.matchup("LAFC", "LA Galaxy", context: "").0?.name, "Los Angeles FC")
        XCTAssertEqual(TeamColors.matchup("Las Vegas Raiders", "Chiefs", context: "").0?.name, "Las Vegas Raiders")
    }

    func testEveryEntryHasColors() {
        XCTAssertTrue(TeamColors.all.allSatisfy { !$0.hex.isEmpty })
    }
}

@MainActor
final class StatsTests: XCTestCase {
    func testStreaksAndHabits() throws {
        let c = try ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = c.mainContext
        func add(_ title: String, _ date: String, _ time: String, _ kind: EventKind, seat: String = "", price: String = "") {
            let p = Pass(title: title); p.date = date; p.time = time; p.kind = kind; p.seat = seat; p.price = price; p.venue = "Metrograph"
            ctx.insert(p)
        }
        // Three Fridays in a row, then a gap.
        add("Knicks vs Celtics", "2026-03-06", "7:30 PM", .sports, seat: "F12", price: "$80")
        add("Mitski", "2026-03-13", "8:00 PM", .concert, seat: "F3", price: "$60")
        add("Past Lives", "2026-03-20", "7:00 PM", .movie, seat: "G8", price: "$18")
        add("Past Lives", "2026-05-01", "7:00 PM", .movie, seat: "F1")
        let s = Stats(try ctx.fetch(FetchDescriptor<Pass>()), now: WhenFormat.day.date(from: "2026-06-01")!)
        XCTAssertEqual(s.visits, 4)
        XCTAssertEqual(s.longestStreak, 3)
        XCTAssertEqual(s.currentStreak, 0)
        XCTAssertEqual(s.favoriteDay, "Friday")
        XCTAssertEqual(s.usualTime, "Evenings")
        XCTAssertEqual(s.favoriteRow?.0, "F")
        XCTAssertEqual(s.mostSeen?.0, "Past Lives")
        XCTAssertEqual(s.spent, 158)
    }
}

@MainActor
final class TBDTests: XCTestCase {
    func testTBD() throws {
        let c = try ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let p = Pass(title: "Liberty vs Aces"); c.mainContext.insert(p)
        XCTAssertTrue(p.dateTBD); XCTAssertTrue(p.timeTBD)
        XCTAssertEqual(p.dateLabel, "Date TBD"); XCTAssertEqual(p.timeLabel, "TBD")
        XCTAssertFalse(p.isArchived)
        p.date = "2026-08-06"
        XCTAssertFalse(p.dateTBD); XCTAssertTrue(p.timeTBD)
        XCTAssertTrue(PassTimes.tbd("TBA")); XCTAssertTrue(PassTimes.tbd("Time TBD")); XCTAssertFalse(PassTimes.tbd("7:30 PM"))
    }
}

@MainActor
final class KindsTests: XCTestCase {
    private var container: ModelContainer!
    override func setUp() async throws {
        container = try ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    func testParseKind() {
        XCTAssertEqual(EventKind.parse("movie"), .movie)
        XCTAssertEqual(EventKind.parse("sports"), .sports)
        XCTAssertEqual(EventKind.parse("Broadway musical"), .theater)
        XCTAssertEqual(EventKind.parse("museum"), .event)
        XCTAssertEqual(EventKind.parse("transit"), .transit)
        XCTAssertEqual(EventKind.parse("boarding pass"), .transit)
        XCTAssertEqual(EventKind.parse("film screening"), .movie)
        XCTAssertEqual(EventKind.parse(""), .movie)
        XCTAssertEqual(TransitMode.parse("Amtrak Northeast Regional"), .train)
        XCTAssertEqual(TransitMode.parse("flight"), .flight)
    }

    func testTransitTimesStayAsPrinted() {
        XCTAssertEqual(PassTimes.normalizeTime("6:05 AM", literal: true), "6:05 AM")
        XCTAssertEqual(PassTimes.normalizeTime("07:15", literal: true), "7:15 AM")
        XCTAssertEqual(PassTimes.normalizeTime("19:40", literal: true), "7:40 PM")
        XCTAssertEqual(PassTimes.normalizeTime("6:05 AM"), "6:05 PM")   // films keep the misread rule
    }

    func testRoute() {
        XCTAssertEqual(Transit.route("nyp", "BOS"), "NYP → BOS")
        XCTAssertEqual(Transit.route("NEW YORK PENN", "Boston South"), "New York Penn → Boston South")
        XCTAssertEqual(Transit.route("", "Philadelphia"), "To Philadelphia")
        XCTAssertNil(Transit.route("", ""))
        XCTAssertEqual(Transit.split("NYP → BOS")?.1, "BOS")
        XCTAssertEqual(Transit.split("Newark to Chicago")?.0, "Newark")
    }

    func testClaudeTransitJSON() throws {
        let p = try Parser.decodeText(#"{"kind":"transit","movieTitle":null,"theater":"NEW YORK PENN STATION","date":"2026-10-14","time":"6:05 AM","seat":"Car 4 Seat 9C","mode":"train","carrier":"Amtrak","trip":"2151","from":"NYP","to":"BOS","arrival":"9:45 AM","gate":"9W","code":"A1B2C3","confidence":0.9}"#)
        XCTAssertEqual(p.kind, .transit)
        XCTAssertEqual(p.title, "NYP → BOS")
        XCTAssertEqual(p.time, "6:05 AM")
        XCTAssertEqual(p.arrival, "9:45 AM")
        XCTAssertEqual(p.trip, "2151")
        let pass = Importer.pass(from: p); container.mainContext.insert(pass)
        XCTAssertEqual(pass.transitMode, .train)
        XCTAssertEqual(pass.kindLine, "TRAIN · AMTRAK 2151")
        XCTAssertEqual(pass.title, "NYP → BOS")
    }

    func testOvernightArrival() {
        let p = Pass(title: "JFK → LHR"); container.mainContext.insert(p); p.kind = .transit
        p.date = "2026-10-14"; p.time = "9:30 PM"; p.arrival = "9:40 AM"
        XCTAssertEqual(p.arrivalDate, p.start.map { Calendar.current.date(byAdding: .minute, value: 12 * 60 + 10, to: $0)! })
    }

    func testLockScreenCodeFitsTheActivity() {
        for (text, sym) in [("https://example.com/ticket/8f2a9c1d4e7b", Symbology.qr), ("AB12CD34EF", .code128), (String(repeating: "X", count: 60), .pdf417)] {
            guard let img = Barcodes.render(text, as: sym, fit: 300) else { return XCTFail("\(sym) didn't draw") }
            let w = img.size.width * img.scale, h = img.size.height * img.scale
            // Never taller than the Lock Screen card; 2D codes inside the 300 px tile.
            XCTAssertLessThanOrEqual(h, 300, "\(sym)")
            if sym == .qr { XCTAssertLessThanOrEqual(w, 300) } else { XCTAssertLessThanOrEqual(w, 900, "\(sym)") }
            XCTAssertGreaterThan(img.size.width, 60)
        }
    }
}


final class ReleaseFixTests: XCTestCase {
    func testTimes() {
        XCTAssertEqual(PassTimes.normalizeTime("09:00"), "9:00 AM")     // a zero-padded 24-hour morning
        XCTAssertEqual(PassTimes.normalizeTime("9:00"), "9:00 PM")      // a bare showtime
        XCTAssertEqual(PassTimes.normalizeTime("7 PM"), "7:00 PM")
        XCTAssertEqual(PassTimes.normalizeTime("7pm"), "7:00 PM")
        XCTAssertEqual(PassTimes.normalizeTime("6:30 AM", literal: true), "6:30 AM")
    }

    func testTitleCaseKeepsNames() {
        XCTAssertEqual(PassTimes.display("AC/DC"), "AC/DC")
        XCTAssertEqual(PassTimes.display("TD GARDEN"), "TD Garden")
        XCTAssertEqual(PassTimes.display("AT&T STADIUM"), "AT&T Stadium")
        XCTAssertEqual(PassTimes.display("T-MOBILE ARENA"), "T-Mobile Arena")
        XCTAssertEqual(PassTimes.display("M3GAN 2.0"), "M3GAN 2.0")
        XCTAssertEqual(PassTimes.display("THE MCKITTRICK HOTEL"), "The McKittrick Hotel")
        XCTAssertEqual(PassTimes.display("NJ TRANSIT"), "NJ Transit")
        XCTAssertEqual(PassTimes.display("SAN DIEGO"), "San Diego")
        XCTAssertEqual(PassTimes.display("RRR"), "RRR")
        XCTAssertEqual(PassTimes.display("Rome"), "Rome")
        XCTAssertEqual(Transit.place("Rome"), "Rome")
    }

    func testPrices() {
        XCTAssertEqual(Stats.price("$17.00"), 17)
        XCTAssertEqual(Stats.price("€12,50"), 12.5)
        XCTAssertEqual(Stats.price("2 x $17.00"), 17)
        XCTAssertEqual(Stats.price("$145.00 + $12.50 fees"), 145)
        XCTAssertEqual(Stats.price("$1,250.00"), 1250)
        XCTAssertEqual(Stats.price("19.50"), 19.5)
        XCTAssertEqual(Stats.price(""), 0)
    }

    func testSellerWholeWords() {
        XCTAssertNil(Seller.detect(text: "PARADISE THEATER  Candice B.", url: nil))
        XCTAssertEqual(Seller.detect(text: "Your DICE ticket", url: nil), .dice)
        XCTAssertEqual(Seller.detect(text: "", url: "https://link.dice.fm/abc"), .dice)
        XCTAssertEqual(Seller.detect(text: "Ticketmaster order", url: nil), .ticketmaster)
    }

    func testHeadliner() {
        XCTAssertEqual(Artists.headliner("The 1975"), "The 1975")
        XCTAssertEqual(Artists.headliner("Florence + the Machine"), "Florence + the Machine")
        XCTAssertEqual(Artists.headliner("Phoebe Bridgers – Reunion Tour"), "Phoebe Bridgers")
        XCTAssertEqual(Artists.headliner("Khruangbin World Tour 2026"), "Khruangbin")
        XCTAssertEqual(Artists.headliner("Mitski with Gold Panda"), "Mitski")
        XCTAssertTrue(Artists.same("The Weeknd", "weeknd"))
        XCTAssertFalse(Artists.same("The", "The Weeknd"))
        XCTAssertTrue(Artists.same("Simon & Garfunkel", "Simon and Garfunkel"))
    }

    func testPatternCodeNeedsADigit() {
        let p = OnDeviceReader.patterns(["ORDER CONFIRMATION", "Order number: 4471-AB92", "FRI OCT 9 7:30 PM"])
        XCTAssertEqual(p.code, "4471-AB92")
        XCTAssertEqual(OnDeviceReader.patterns(["BOOKING REFERENCE", "-----"]).code, "")
        // An email address isn't a game.
        XCTAssertNotEqual(OnDeviceReader.patterns(["tickets@venue.com", "FRI OCT 9 7:30 PM"]).kind, .sports)
        XCTAssertNil(OnDeviceReader.date(in: "MARVEL 2 IMAX"))
        XCTAssertNil(OnDeviceReader.date(in: "JUNCTION 3"))
        XCTAssertEqual(OnDeviceReader.date(in: "Sept. 12"), "09-12")
    }
}

@MainActor
final class ShowingTests: XCTestCase {
    private var container: ModelContainer!
    override func setUp() async throws {
        container = try ModelContainer(for: Pass.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func pass(_ title: String, _ date: String, _ time: String, seat: String = "", group: UUID? = nil) -> Pass {
        let p = Pass(title: title); p.date = date; p.time = time; p.seat = seat; p.venue = "Metrograph"
        if let group { p.group = group }
        container.mainContext.insert(p)
        return p
    }

    func testSeatsInPrintedOrderAndOneReminderPairPerShowing() {
        let g = UUID()
        let future = Calendar.current.date(byAdding: .day, value: 10, to: Date())!
        let day = WhenFormat.day.string(from: future)
        let a = pass("Digger", day, "7:30 PM", seat: "F10", group: g)
        let b = pass("Digger", day, "7:30 PM", seat: "F9", group: g)
        let c = pass("Digger", day, "7:30 PM", seat: "F11", group: g)
        XCTAssertEqual(Showings.sortSeats([a, b, c]).map(\.seat), ["F9", "F10", "F11"])
        let items = Reminders.plan([a, b, c])
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items[1].body.contains("Seats F9, F10, F11"))
    }

    func testCalendarPlan() {
        let future = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
        let day = WhenFormat.day.string(from: future)
        let timed = pass("Digger", day, "7:30 PM", seat: "G13")
        timed.runtime = 120
        let tbd = pass("Liberty vs Aces", day, "")
        tbd.kind = .sports
        let undated = pass("Hamlet", "", "")
        let plans = CalendarSync.plan([timed, tbd, undated])
        XCTAssertEqual(plans.count, 2)                      // no date, no event
        let p = plans.first { $0.title == "Digger" }!
        XCTAssertFalse(p.allDay)
        XCTAssertEqual(p.end.timeIntervalSince(p.start), 135 * 60)   // runtime + 15
        XCTAssertTrue(p.notes.contains("Seat: G13"))
        XCTAssertTrue(plans.first { $0.title == "Liberty vs Aces" }!.allDay)
    }

    func testOldStubKeepsItsYearAndIsPast() {
        let p = pass("Paris, Texas", "2019-05-04", "7:00 PM")
        XCTAssertTrue(p.isArchived)
        XCTAssertTrue(Reminders.plan([p]).isEmpty)
    }
}

final class FoldTests: XCTestCase {
    func testInnerDisplayOpenAndUpright() {
        XCTAssertEqual(Fold.of(CGSize(width: 890, height: 626)), .open)
        XCTAssertEqual(Fold.of(CGSize(width: 626, height: 890)), .upright)
    }

    func testPhonesOuterDisplayAndSplitViewGetThePhoneLayout() {
        XCTAssertEqual(Fold.of(CGSize(width: 440, height: 956)), .phone)   // Pro Max
        XCTAssertEqual(Fold.of(CGSize(width: 956, height: 440)), .phone)   // Pro Max, landscape
        XCTAssertEqual(Fold.of(CGSize(width: 445, height: 626)), .phone)   // half of the inner display in Split View
    }
}

import XCTest
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
        XCTAssertEqual(TicketDate.resolveFromModel("2024-12-18", today: day(2026, 9, 28), calendar: cal), "2026-12-18")
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

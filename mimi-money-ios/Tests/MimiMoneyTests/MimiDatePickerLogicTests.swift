import XCTest
@testable import MimiMoneyCore

final class MimiDatePickerLogicTests: XCTestCase {
    private var cal: Calendar { MimiDatePickerLogic.calendar }

    func testMonthTitleFormat() {
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 14))!
        XCTAssertEqual(MimiDatePickerLogic.monthTitle(for: date), "2026年11月")
    }

    func testTimeCapsuleTextPadsHourMinute() {
        let date = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 9, minute: 5))!
        XCTAssertEqual(MimiDatePickerLogic.timeCapsuleText(for: date), "09:05")
    }

    func testCombiningKeepsTimeFromSource() {
        let day = cal.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 0, minute: 0))!
        let time = cal.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 16, minute: 42))!
        let merged = MimiDatePickerLogic.combining(day: day, timeFrom: time)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: merged)
        XCTAssertEqual(comps.year, 2026)
        XCTAssertEqual(comps.month, 10)
        XCTAssertEqual(comps.day, 3)
        XCTAssertEqual(comps.hour, 16)
        XCTAssertEqual(comps.minute, 42)
    }

    func testSettingHourMinuteClamps() {
        let base = cal.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12, minute: 0))!
        let clamped = MimiDatePickerLogic.setting(hour: 99, minute: -3, on: base)
        let comps = cal.dateComponents([.hour, .minute, .day], from: clamped)
        XCTAssertEqual(comps.hour, 23)
        XCTAssertEqual(comps.minute, 0)
        XCTAssertEqual(comps.day, 8)
    }

    func testShiftMonth() {
        let nov = cal.date(from: DateComponents(year: 2026, month: 11, day: 14))!
        let oct = MimiDatePickerLogic.shiftMonth(-1, from: nov)
        let dec = MimiDatePickerLogic.shiftMonth(1, from: nov)
        XCTAssertEqual(MimiDatePickerLogic.monthTitle(for: oct), "2026年10月")
        XCTAssertEqual(MimiDatePickerLogic.monthTitle(for: dec), "2026年12月")
    }

    func testDaysInMonthSundayFirstLeadingPads() {
        // 2026-11-01 is Sunday → no leading pads
        let nov = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let novDays = MimiDatePickerLogic.daysInMonth(for: nov)
        XCTAssertEqual(novDays.count % 7, 0)
        guard let firstNov = novDays.first, let firstNovDay = firstNov else {
            return XCTFail("November grid should start on day 1")
        }
        XCTAssertEqual(cal.component(.day, from: firstNovDay), 1)

        // 2026-10-01 is Thursday → 4 leading nils (Sun–Wed)
        let oct = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        let octDays = MimiDatePickerLogic.daysInMonth(for: oct)
        XCTAssertNil(octDays[0])
        XCTAssertNil(octDays[1])
        XCTAssertNil(octDays[2])
        XCTAssertNil(octDays[3])
        XCTAssertEqual(cal.component(.day, from: octDays[4]!), 1)
    }

    func testWeekdayLabelsSundayFirst() {
        XCTAssertEqual(MimiDatePickerLogic.weekdayLabels, ["日", "一", "二", "三", "四", "五", "六"])
    }
}

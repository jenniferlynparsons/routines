import Foundation

// MARK: - Routine definitions (parsed from routines.txt)

struct RoutineItem: Identifiable, Hashable {
    /// Stable identity: "Section|Item text". Editing the text makes it a new item.
    let id: String
    let text: String
    /// Calendar weekday numbers: 1 = Sunday … 7 = Saturday.
    let days: Set<Int>
    /// Obligations carry over until checked. Habits reset each day.
    let carries: Bool
}

struct RoutineSection: Identifiable, Hashable {
    var id: String { name }
    let name: String
    /// Minutes after midnight when this section becomes current.
    let startMinutes: Int
    var items: [RoutineItem]
}

// MARK: - Saved progress (state.json)

struct CarriedItem: Codable, Hashable, Identifiable {
    var itemID: String
    var text: String
    /// The day it was due, as yyyy-MM-dd.
    var originDay: String
    var id: String { "carried|\(itemID)|\(originDay)" }
}

struct Priority: Codable, Equatable {
    var text: String
    var done: Bool

    static let empty = Priority(text: "", done: false)
    var isBlank: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct SavedState: Codable, Equatable {
    /// The day `checked` belongs to, as yyyy-MM-dd.
    var day: String
    var checked: Set<String>
    var carried: [CarriedItem]
    /// Today's top priorities, typed in the app.
    var priorities: [Priority]

    init(day: String, checked: Set<String>, carried: [CarriedItem], priorities: [Priority] = []) {
        self.day = day
        self.checked = checked
        self.carried = carried
        self.priorities = priorities
    }

    // Reads state.json files saved before priorities existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        day = try c.decode(String.self, forKey: .day)
        checked = try c.decode(Set<String>.self, forKey: .checked)
        carried = try c.decode([CarriedItem].self, forKey: .carried)
        priorities = try c.decodeIfPresent([Priority].self, forKey: .priorities) ?? []
    }
}

// MARK: - What shows today

struct PlannedSection: Identifiable {
    let id: String
    let name: String
    let startMinutes: Int
    let carried: [CarriedItem]
    let items: [RoutineItem]

    var allIDs: [String] { carried.map(\.id) + items.map(\.id) }
}

// MARK: - Helpers

enum DayKey {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
}

enum Weekdays {
    static let workweek: Set<Int> = [2, 3, 4, 5, 6]
    static let all: Set<Int> = Set(1...7)

    static let lookup: [String: Set<Int>] = {
        var map: [String: Set<Int>] = [
            "weekdays": Weekdays.workweek, "weekday": Weekdays.workweek, "workdays": Weekdays.workweek,
            "weekends": [1, 7], "weekend": [1, 7],
            "daily": Weekdays.all, "everyday": Weekdays.all,
        ]
        let names: [(Int, [String])] = [
            (1, ["sun", "sunday"]),
            (2, ["mon", "monday"]),
            (3, ["tue", "tues", "tuesday"]),
            (4, ["wed", "weds", "wednesday"]),
            (5, ["thu", "thur", "thurs", "thursday"]),
            (6, ["fri", "friday"]),
            (7, ["sat", "saturday"]),
        ]
        for (number, keys) in names {
            for key in keys { map[key] = [number] }
        }
        return map
    }()
}

enum TimeText {
    static func string(minutes: Int) -> String {
        let date = Calendar.current.date(
            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Parser

enum RoutineParser {
    static func parse(_ text: String) -> [RoutineSection] {
        var sections: [RoutineSection] = []
        var current: RoutineSection?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") { continue }

            if line.hasPrefix("#") {
                if let finished = current { sections.append(finished) }
                current = parseHeader(line, fallbackStart: sections.last?.startMinutes ?? 0)
                continue
            }

            if current == nil {
                current = RoutineSection(name: "Today", startMinutes: 0, items: [])
            }
            if let section = current, let item = parseItem(line, sectionName: section.name) {
                current?.items.append(item)
            }
        }
        if let finished = current { sections.append(finished) }

        // Order by start time, keeping file order for ties.
        return sections.enumerated()
            .sorted { ($0.element.startMinutes, $0.offset) < ($1.element.startMinutes, $1.offset) }
            .map(\.element)
    }

    static func parseHeader(_ line: String, fallbackStart: Int) -> RoutineSection {
        var body = String(line.drop(while: { $0 == "#" })).trimmingCharacters(in: .whitespaces)
        var start = fallbackStart
        if let at = body.lastIndex(of: "@") {
            let timePart = String(body[body.index(after: at)...])
            if let minutes = parseTime(timePart) { start = minutes }
            body = String(body[..<at]).trimmingCharacters(in: .whitespaces)
        }
        return RoutineSection(name: body.isEmpty ? "Untitled" : body, startMinutes: start, items: [])
    }

    /// Accepts 8, 8:00, 16:00, 4pm, 4:30 pm.
    static func parseTime(_ raw: String) -> Int? {
        var t = raw.lowercased().replacingOccurrences(of: " ", with: "")
        var pm = false
        var am = false
        if t.hasSuffix("pm") { pm = true; t.removeLast(2) }
        else if t.hasSuffix("am") { am = true; t.removeLast(2) }

        let parts = t.split(separator: ":")
        guard let first = parts.first, let h = Int(first), (0...23).contains(h) else { return nil }
        let m = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        var hour = h
        if pm && hour < 12 { hour += 12 }
        if am && hour == 12 { hour = 0 }
        return hour * 60 + min(max(m, 0), 59)
    }

    static func parseItem(_ line: String, sectionName: String) -> RoutineItem? {
        var text = line
        for prefix in ["- [ ] ", "- ", "* ", "• "] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }

        var days = Weekdays.workweek
        var carries = false

        // Trailing tags, e.g. "Submit timesheet [Fri, carry]"
        if text.hasSuffix("]"), let open = text.lastIndex(of: "[") {
            let inside = text[text.index(after: open)..<text.index(before: text.endIndex)]
            let tokens = inside.lowercased()
                .split(whereSeparator: { $0 == "," || $0 == " " || $0 == "/" })
                .map(String.init)

            var tagDays: Set<Int> = []
            var recognized = false
            for token in tokens {
                if ["carry", "carries", "carryover"].contains(token) {
                    carries = true
                    recognized = true
                } else if let d = Weekdays.lookup[token] {
                    tagDays.formUnion(d)
                    recognized = true
                }
            }
            // Brackets with nothing we recognize stay part of the text.
            if recognized {
                if !tagDays.isEmpty { days = tagDays }
                text = String(text[..<open])
            }
        }

        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return RoutineItem(id: "\(sectionName)|\(text)", text: text, days: days, carries: carries)
    }
}

// MARK: - Scheduling rules

enum Schedule {
    /// Moves to a new day: habits reset, and any obligation that was due on a
    /// day since the last open and never checked becomes a carried item.
    static func rollOver(_ state: SavedState, sections: [RoutineSection], to today: Date,
                         calendar: Calendar = .current) -> SavedState {
        let todayKey = DayKey.key(today)
        guard state.day != todayKey else { return state }

        // Carried items checked off on the last day are finished.
        var carried = state.carried.filter { !state.checked.contains($0.id) }

        if var cursor = DayKey.date(state.day) {
            let todayStart = calendar.startOfDay(for: today)
            var steps = 0
            // Walk every day from the last open up to yesterday, so a Friday the
            // laptop stayed closed still carries its timesheet to Monday.
            while cursor < todayStart && steps < 31 {
                let key = DayKey.key(cursor)
                let weekday = calendar.component(.weekday, from: cursor)
                for section in sections {
                    for item in section.items where item.carries && item.days.contains(weekday) {
                        let doneThatDay = key == state.day && state.checked.contains(item.id)
                        let alreadyCarried = carried.contains { $0.itemID == item.id && $0.originDay == key }
                        if !doneThatDay && !alreadyCarried {
                            carried.append(CarriedItem(itemID: item.id, text: item.text, originDay: key))
                        }
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
                steps += 1
            }
        }

        // Unfinished priorities move up and wait for tomorrow's review; finished ones clear.
        let priorities = state.priorities.filter { !$0.done && !$0.isBlank }

        return SavedState(day: todayKey, checked: [], carried: carried, priorities: priorities)
    }

    /// Today's sections. Carried items sit at the top of the first section.
    static func plan(sections: [RoutineSection], state: SavedState, today: Date,
                     calendar: Calendar = .current) -> [PlannedSection] {
        let weekday = calendar.component(.weekday, from: today)
        var result: [PlannedSection] = []

        for (index, section) in sections.enumerated() {
            let items = section.items.filter { $0.days.contains(weekday) }
            let carried = index == 0 ? state.carried : []
            if items.isEmpty && carried.isEmpty { continue }
            result.append(PlannedSection(id: section.id, name: section.name,
                                         startMinutes: section.startMinutes,
                                         carried: carried, items: items))
        }

        if sections.isEmpty && !state.carried.isEmpty {
            result.append(PlannedSection(id: "Carried over", name: "Carried over",
                                         startMinutes: 0, carried: state.carried, items: []))
        }
        return result
    }

    /// The section whose start time has most recently passed.
    static func currentIndex(in plan: [PlannedSection], at date: Date,
                             calendar: Calendar = .current) -> Int? {
        guard !plan.isEmpty else { return nil }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return plan.lastIndex { $0.startMinutes <= minutes } ?? 0
    }

    static func originLabel(_ key: String, today: Date, calendar: Calendar = .current) -> String {
        guard let date = DayKey.date(key) else { return "carried over" }
        let days = calendar.dateComponents([.day], from: date, to: calendar.startOfDay(for: today)).day ?? 0
        if days == 1 { return "from yesterday" }
        if days < 7 { return "from " + date.formatted(.dateTime.weekday(.abbreviated)) }
        return "from " + date.formatted(.dateTime.month(.abbreviated).day())
    }
}

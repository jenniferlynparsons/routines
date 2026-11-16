import SwiftUI
import AppKit

/// Owns the routines file, the saved progress, and the clock.
final class RoutineStore: ObservableObject {
    @Published private(set) var sections: [RoutineSection] = []
    @Published private(set) var state: SavedState
    @Published private(set) var now = Date()
    @Published private(set) var problem: String?
    /// Sections opened or closed by hand. The view clears this when the current section changes.
    @Published var expanded: [String: Bool] = [:]

    let folderURL: URL
    let routinesURL: URL
    private let stateURL: URL
    private var routinesModified: Date?

    init() {
        let fm = FileManager.default
        let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fm.homeDirectoryForCurrentUser
        folderURL = documents.appendingPathComponent("Routines", isDirectory: true)
        routinesURL = folderURL.appendingPathComponent("routines.txt")
        stateURL = folderURL.appendingPathComponent("state.json")
        state = SavedState(day: DayKey.key(Date()), checked: [], carried: [])

        prepareFolder()
        loadRoutines()
        loadState()
        refresh()
    }

    // MARK: Reading

    var plan: [PlannedSection] {
        Schedule.plan(sections: sections, state: state, today: now)
    }

    func isChecked(_ id: String) -> Bool {
        state.checked.contains(id)
    }

    // MARK: Actions

    /// Called on a timer and whenever the app comes to the front.
    func refresh() {
        now = Date()
        reloadIfChanged()
        let rolled = Schedule.rollOver(state, sections: sections, to: now)
        if rolled != state {
            state = rolled
            saveState()
        }
    }

    func toggle(_ id: String) {
        refresh() // make sure a check after midnight lands on the right day
        if state.checked.contains(id) {
            state.checked.remove(id)
        } else {
            state.checked.insert(id)
        }
        saveState()
    }

    // MARK: Priorities

    static let priorityCount = 5

    func priority(_ index: Int) -> Priority {
        index < state.priorities.count ? state.priorities[index] : .empty
    }

    func setPriorityText(_ index: Int, _ text: String) {
        fillPrioritySlots()
        state.priorities[index].text = text
        if state.priorities[index].isBlank { state.priorities[index].done = false }
        saveState()
    }

    func togglePriority(_ index: Int) {
        fillPrioritySlots()
        guard !state.priorities[index].isBlank else { return }
        state.priorities[index].done.toggle()
        saveState()
    }

    private func fillPrioritySlots() {
        while state.priorities.count < Self.priorityCount {
            state.priorities.append(.empty)
        }
    }

    func openRoutinesFile() {
        NSWorkspace.shared.open(routinesURL)
    }

    func revealFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([routinesURL])
    }

    // MARK: Files

    private func prepareFolder() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: routinesURL.path) {
                try Self.starterRoutines.write(to: routinesURL, atomically: true, encoding: .utf8)
            }
        } catch {
            problem = "Couldn't set up \(folderURL.path): \(error.localizedDescription)"
        }
    }

    private func loadRoutines() {
        do {
            let text = try String(contentsOf: routinesURL, encoding: .utf8)
            sections = RoutineParser.parse(text)
            routinesModified = modificationDate(of: routinesURL)
            problem = nil
        } catch {
            problem = "Couldn't read routines.txt: \(error.localizedDescription)"
        }
    }

    private func reloadIfChanged() {
        if modificationDate(of: routinesURL) != routinesModified {
            loadRoutines()
        }
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: stateURL),
              let saved = try? JSONDecoder().decode(SavedState.self, from: data) else { return }
        state = saved
    }

    private func saveState() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try encoder.encode(state).write(to: stateURL, options: .atomic)
        } catch {
            problem = "Couldn't save progress: \(error.localizedDescription)"
        }
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    // MARK: First-run file

    static let starterRoutines = """
    // Routines — edit this file, save it, and the app picks up the changes.
    //
    // "# Name @ time" starts a section. The app shows the section whose time
    // has most recently passed. Times can be 8:00, 16:00, or 4:30pm.
    //
    // Each line under a section is one item. Items show Monday–Friday unless
    // you add days in brackets at the end: [Fri]  [Mon, Wed]  [daily]  [weekends]
    //
    // Add "carry" to keep an item around until it's done. If it isn't checked
    // off, it shows up at the top of the next morning:  [Fri, carry]
    //
    // Lines starting with // are notes and are ignored.

    # Morning @ 8:00
    Check email
    Check team chat
    Choose today's Top 5
    Prep for meetings

    # Afternoon @ 12:00
    Review the week [Fri, carry]
    Submit timesheet [Fri, carry]

    # End of day @ 16:00
    Write down tomorrow's first task
    Close open tabs

    """
}

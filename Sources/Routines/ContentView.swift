import SwiftUI
import AppKit
import Combine

struct ContentView: View {
    @EnvironmentObject var store: RoutineStore
    @AppStorage("floatOnTop") var floatOnTop = true

    let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        let plan = store.plan
        let currentIndex = Schedule.currentIndex(in: plan, at: store.now)
        let currentID = currentIndex.map { plan[$0].id }

        VStack(alignment: .leading, spacing: 0) {
            topBar
            header(plan: plan)
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            Divider()
                .padding(.horizontal, 16)
                .opacity(0.6)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let problem = store.problem {
                        ProblemBanner(message: problem)
                    }
                    PrioritiesSection()
                    if plan.isEmpty {
                        EmptyDay()
                    }
                    ForEach(Array(plan.enumerated()), id: \.element.id) { index, section in
                        SectionView(
                            section: section,
                            isCurrent: index == currentIndex,
                            isExpanded: expansionBinding(for: section, index: index, currentIndex: currentIndex),
                            today: store.now)
                    }
                    if isAllDone(plan) {
                        DoneNote()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.never)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 260, minHeight: 260)
        .background(
            ZStack {
                VisualEffectBackground()
                Theme.wash
            }
            .ignoresSafeArea()
        )
        .background(WindowConfigurator(floating: floatOnTop))
        .tint(Theme.strong)
        .foregroundStyle(Theme.ink)
        .fontDesign(.rounded)
        .onReceive(ticker) { _ in store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.refresh()
        }
        .onChange(of: currentID) {
            withAnimation(.snappy) { store.expanded = [:] }
        }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 2) {
            Spacer()
            IconButton(systemName: floatOnTop ? "pin.fill" : "pin",
                       help: floatOnTop ? "Stop floating on top" : "Float on top of other windows",
                       isActive: floatOnTop) {
                floatOnTop.toggle()
            }
            IconButton(systemName: "square.and.pencil", help: "Edit routines (⌘E)") {
                store.openRoutinesFile()
            }
        }
        .frame(height: 30)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    private func header(plan: [PlannedSection]) -> some View {
        let ids = plan.flatMap(\.allIDs)
        let done = ids.filter { store.isChecked($0) }.count

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(store.now.formatted(.dateTime.weekday(.wide)))
                    .font(.system(size: 24, weight: .semibold))
                Text(store.now.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            if !ids.isEmpty {
                ProgressRing(done: done, total: ids.count)
            }
        }
    }

    // MARK: Logic

    private func expansionBinding(for section: PlannedSection, index: Int, currentIndex: Int?) -> Binding<Bool> {
        Binding(
            get: { store.expanded[section.id] ?? defaultExpanded(section, index: index, currentIndex: currentIndex) },
            set: { store.expanded[section.id] = $0 }
        )
    }

    /// Current section open; earlier sections open only if something is left; later sections closed.
    private func defaultExpanded(_ section: PlannedSection, index: Int, currentIndex: Int?) -> Bool {
        guard let current = currentIndex else { return true }
        if index == current { return true }
        if index < current { return section.allIDs.contains { !store.isChecked($0) } }
        return false
    }

    private func isAllDone(_ plan: [PlannedSection]) -> Bool {
        let ids = plan.flatMap(\.allIDs)
        return !ids.isEmpty && ids.allSatisfy { store.isChecked($0) }
    }
}

// MARK: - Section

struct SectionView: View {
    @EnvironmentObject var store: RoutineStore
    let section: PlannedSection
    let isCurrent: Bool
    @Binding var isExpanded: Bool
    let today: Date

    var body: some View {
        let ids = section.allIDs
        let done = ids.filter { store.isChecked($0) }.count

        VStack(alignment: .leading, spacing: 2) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    if isCurrent {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                    }
                    Text(section.name.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.9)
                        .foregroundStyle(isCurrent ? Theme.strong : Theme.muted)
                    if section.startMinutes > 0 {
                        Text(TimeText.string(minutes: section.startMinutes))
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(done)/\(ids.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.faint)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")

            if isExpanded {
                VStack(spacing: 1) {
                    ForEach(section.carried) { carried in
                        ItemRow(id: carried.id, text: carried.text,
                                badge: Schedule.originLabel(carried.originDay, today: today))
                    }
                    ForEach(section.items) { item in
                        ItemRow(id: item.id, text: item.text, badge: nil)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Top 5

struct PrioritiesSection: View {
    @EnvironmentObject var store: RoutineStore

    var body: some View {
        let slots = (0..<RoutineStore.priorityCount).map { store.priority($0) }
        let filled = slots.filter { !$0.isBlank }
        let done = filled.filter(\.done).count

        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("TOP 5 THIS WEEK")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(Theme.strong)
                Spacer()
                if !filled.isEmpty {
                    Text("\(done)/\(filled.count)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)

            VStack(spacing: 1) {
                ForEach(0..<RoutineStore.priorityCount, id: \.self) { index in
                    PriorityRow(index: index)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent.opacity(0.16))
        )
    }
}

struct PriorityRow: View {
    @EnvironmentObject var store: RoutineStore
    let index: Int

    var body: some View {
        let priority = store.priority(index)

        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.2)) { store.togglePriority(index) }
            } label: {
                CheckCircle(checked: priority.done)
                    .opacity(priority.isBlank ? 0.35 : 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(priority.isBlank)
            .help(priority.done ? "Mark not done" : "Mark done")

            if priority.done {
                // Uncheck to edit a finished priority.
                Text(priority.text)
                    .font(.system(size: 13.5))
                    .strikethrough(true, color: Theme.faint)
                    .foregroundStyle(Theme.faint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("", text: textBinding,
                          prompt: Text(index == 0 ? "Most important thing this week" : "Priority \(index + 1)")
                            .foregroundStyle(Theme.faint))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { store.priority(index).text },
            set: { store.setPriorityText(index, $0) }
        )
    }
}

// MARK: - Item

struct ItemRow: View {
    @EnvironmentObject var store: RoutineStore
    let id: String
    let text: String
    let badge: String?
    @StateObject var hover = HoverState()

    var body: some View {
        let checked = store.isChecked(id)

        HStack(spacing: 10) {
            CheckCircle(checked: checked)
            Text(text)
                .font(.system(size: 13.5))
                .strikethrough(checked, color: Theme.faint)
                .foregroundStyle(checked ? Theme.faint : Theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if let badge {
                Text(badge)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent.opacity(checked ? 0.15 : 0.4)))
                    .foregroundStyle(Theme.strong.opacity(checked ? 0.55 : 1))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.ink.opacity(hover.isOn ? 0.07 : 0))
        )
        .contentShape(Rectangle())
        .onHover { hover.isOn = $0 }
        .onTapGesture {
            withAnimation(.snappy(duration: 0.2)) { store.toggle(id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(checked ? "Done" : "Not done")
    }
}

struct CheckCircle: View {
    let checked: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(checked ? Theme.accent : Theme.muted, lineWidth: 1.5)
            Circle()
                .fill(Theme.accent)
                .scaleEffect(checked ? 1 : 0.2)
                .opacity(checked ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 8.5, weight: .heavy))
                .foregroundStyle(Theme.onAccent)
                .opacity(checked ? 1 : 0)
        }
        .frame(width: 17, height: 17)
    }
}

// MARK: - Small pieces

/// Hover tracking without @State, which needs full Xcode on the newest SDK.
final class HoverState: ObservableObject {
    @Published var isOn = false
}

struct ProgressRing: View {
    let done: Int
    let total: Int

    var body: some View {
        let fraction = total == 0 ? 0 : Double(done) / Double(total)

        ZStack {
            Circle()
                .stroke(Theme.faint.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(done)/\(total)")
                .font(.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 42, height: 42)
        .animation(.snappy, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) done")
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    var isActive = false
    let action: () -> Void
    @StateObject var hover = HoverState()

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Theme.strong : Theme.muted)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.ink.opacity(hover.isOn ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover.isOn = $0 }
        .help(help)
    }
}

struct DoneNote: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Theme.accent)
            Text("All done for today.")
                .foregroundStyle(Theme.muted)
        }
        .font(.system(size: 12.5, weight: .medium))
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .transition(.opacity)
    }
}

struct EmptyDay: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max")
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            Text("Nothing scheduled today.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}

struct ProblemBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
    }
}

// MARK: - AppKit bridges

/// Frosted-glass window background, like Control Center or a sidebar.
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active // stay frosted when the window isn't focused
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Reaches the hosting NSWindow to set floating, dragging, and frame memory.
struct WindowConfigurator: NSViewRepresentable {
    let floating: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { apply(to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { apply(to: nsView.window) }
    }

    private func apply(to window: NSWindow?) {
        guard let window else { return }
        window.level = floating ? .floating : .normal
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.zoomButton)?.isHidden = true
        if window.frameAutosaveName.isEmpty {
            window.setFrameAutosaveName("RoutinesMainWindow")
        }
    }
}

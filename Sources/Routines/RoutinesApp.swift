import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct RoutinesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = RoutineStore()

    var body: some Scene {
        Window("Routines", id: "main") {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 300, height: 500)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Edit Routines…") { store.openRoutinesFile() }
                    .keyboardShortcut("e")
                Button("Show Routines Folder") { store.revealFolder() }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
        }
    }
}

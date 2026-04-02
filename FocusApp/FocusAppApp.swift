// FocusApp/FocusAppApp.swift
import SwiftUI

@main
struct FocusAppApp: App {
    @StateObject private var taskStore = TaskStore()
    @StateObject private var sessionManager = SessionManager()

    var body: some Scene {
        WindowGroup {
            MainWindowView(
                taskStore: taskStore,
                sessionManager: sessionManager,
                onStartFocus: { task in
                    sessionManager.startSession(task: task)
                }
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

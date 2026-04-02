// FocusApp/Views/MainWindowView.swift
import SwiftUI

struct MainWindowView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var sessionManager: SessionManager
    var onStartFocus: (FocusTask) -> Void

    @State private var newTaskTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Focus")
                    .font(.system(size: 20, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Task list
            if taskStore.tasks.isEmpty {
                VStack {
                    Spacer()
                    Text("No tasks yet. Add one below.")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(taskStore.tasks) { task in
                            TaskRowView(
                                task: task,
                                isActiveSession: sessionManager.activeSession?.task.id == task.id,
                                onFocus: { onStartFocus(task) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }

            Divider()

            // Add task row
            HStack(spacing: 8) {
                TextField("Add a task...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit { submitNewTask() }
                Button(action: submitNewTask) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 320, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func submitNewTask() {
        taskStore.add(title: newTaskTitle)
        newTaskTitle = ""
    }
}

struct TaskRowView: View {
    let task: FocusTask
    let isActiveSession: Bool
    let onFocus: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isComplete ? "checkmark.square.fill" : "square")
                .foregroundColor(task.isComplete ? .secondary : .primary)
                .font(.system(size: 14))

            Text(task.title)
                .font(.callout)
                .strikethrough(task.isComplete)
                .foregroundColor(task.isComplete ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if !task.isComplete {
                Button(isActiveSession ? "Focusing" : "Focus") {
                    onFocus()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isActiveSession)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActiveSession ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        )
    }
}

// FocusApp/Views/NudgeView.swift
import SwiftUI
import AppKit

struct NudgeView: View {
    let appName: String
    @ObservedObject var escalationManager: EscalationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Color.orange).frame(width: 7, height: 7)
                Text("Hey, you drifted a bit")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            Text("You've been on \(appName). Still on task?")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.7))

            HStack(spacing: 8) {
                Button("I need this") {
                    Task { await handleINeedThis() }
                }
                .buttonStyle(FocusButtonStyle(color: .orange))

                Button("Get me back") {
                    escalationManager.dismissNudge()
                }
                .buttonStyle(FocusButtonStyle(color: .green))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
    }

    private func handleINeedThis() async {
        let result = await NSApp.keyWindow?.runTextInputAlert(
            title: "What do you need it for?",
            message: "Tell the AI why you need \(appName) right now."
        )
        guard let request = result, !request.isEmpty else { return }
        let decision = await escalationManager.requestUnlock(request: request)
        if case .denied(let reason) = decision {
            print("[Focus] Denied: \(reason)")
        }
    }
}

extension NSWindow {
    func runTextInputAlert(title: String, message: String) async -> String? {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = title
                alert.informativeText = message
                alert.addButton(withTitle: "Ask AI")
                alert.addButton(withTitle: "Cancel")
                let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
                input.placeholderString = "e.g. I need a tutorial video"
                alert.accessoryView = input
                let response = alert.runModal()
                continuation.resume(returning: response == .alertFirstButtonReturn ? input.stringValue : nil)
            }
        }
    }
}

struct FocusButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(color, lineWidth: 1))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

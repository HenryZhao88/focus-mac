// FocusApp/Views/OverlayView.swift
import SwiftUI

struct OverlayView: View {
    @ObservedObject var escalationManager: EscalationManager
    @ObservedObject var sessionManager: SessionManager

    var body: some View {
        Group {
            switch escalationManager.state {
            case .monitoring:
                SlimBarView(sessionManager: sessionManager, onEnd: {
                    escalationManager.stopMonitoring()
                    sessionManager.endSession()
                })
            case .nudging(_, let appName):
                NudgeView(
                    appName: appName,
                    escalationManager: escalationManager
                )
            case .blocking:
                BlockView(escalationManager: escalationManager)
            }
        }
    }
}

struct SlimBarView: View {
    @ObservedObject var sessionManager: SessionManager
    let onEnd: () -> Void

    @State private var elapsed = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
            Text(sessionManager.activeSession?.task.title ?? "")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Text(elapsed)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            Button("■") { onEnd() }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.75))
        )
        .onReceive(timer) { _ in
            elapsed = sessionManager.activeSession?.elapsedFormatted ?? ""
        }
        .onAppear {
            elapsed = sessionManager.activeSession?.elapsedFormatted ?? ""
        }
    }
}

// MARK: - Stubs (replaced in Task 10)
struct NudgeView: View {
    let appName: String
    @ObservedObject var escalationManager: EscalationManager
    var body: some View {
        Text("Nudge: \(appName)")
            .foregroundColor(.orange)
            .padding()
    }
}

struct BlockView: View {
    @ObservedObject var escalationManager: EscalationManager
    var body: some View {
        Text("Blocked")
            .foregroundColor(.red)
            .padding()
    }
}

// FocusApp/Views/BlockView.swift
import SwiftUI

struct BlockView: View {
    @ObservedObject var escalationManager: EscalationManager

    @State private var requestText = ""
    @State private var aiResponse: String?
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 16) {
            Text("🚫")
                .font(.system(size: 28))

            Text("Focus time.")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#ff6584"))

            Text("Back to: \(escalationManager.sessionManager.activeSession?.task.title ?? "your task")")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.6))

            Divider().background(Color.white.opacity(0.1))

            VStack(alignment: .leading, spacing: 8) {
                Text("Need something? Ask the AI")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    TextField("e.g. I need this for a tutorial", text: $requestText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(7)
                        .onSubmit { Task { await submitRequest() } }

                    Button(action: { Task { await submitRequest() } }) {
                        if isLoading {
                            ProgressView().scaleEffect(0.6)
                        } else {
                            Text("Ask")
                                .font(.system(size: 12, weight: .semibold))
                        }
                    }
                    .buttonStyle(FocusButtonStyle(color: Color(hex: "#ff6584")))
                    .disabled(requestText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }

                if let response = aiResponse {
                    Text(response)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.7))
                        .padding(.top, 2)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
    }

    private func submitRequest() async {
        let trimmed = requestText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isLoading = true
        let decision = await escalationManager.requestUnlock(request: trimmed)
        isLoading = false
        switch decision {
        case .approved(let msg):
            aiResponse = msg.map { "✓ \($0)" } ?? "✓ Approved — go for it!"
            requestText = ""
        case .denied(let reason):
            aiResponse = "✗ \(reason)"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

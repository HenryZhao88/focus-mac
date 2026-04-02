// FocusApp/Services/WebSocketServer.swift
import Foundation
import Network

final class WebSocketServer {

    // MARK: - Public API

    /// Called on the main queue whenever the active tab URL changes.
    /// Receives `nil` when the client disconnects.
    var onURLChange: ((String?) -> Void)?

    // MARK: - Private

    private var listener: NWListener?
    private var connection: NWConnection?
    private let wsQueue = DispatchQueue(label: "com.focusapp.ws")

    // MARK: - Lifecycle

    func start() {
        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)

        // Append WebSocket framer on top of TCP
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        guard let listener = try? NWListener(using: params, on: NWEndpoint.Port(rawValue: Constants.wsPort)!) else {
            return
        }
        self.listener = listener

        listener.newConnectionHandler = { [weak self] newConnection in
            guard let self else { return }
            // Cancel existing connection before accepting the new one
            self.connection?.cancel()
            self.connection = newConnection
            newConnection.start(queue: self.wsQueue)
            self.receive(on: newConnection)
        }

        listener.stateUpdateHandler = { state in
            // No-op for now; listener manages its own lifecycle
            _ = state
        }

        listener.start(queue: wsQueue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
    }

    // MARK: - Receiving

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self else { return }

            // Check connection state — fire nil callback on disconnect/failure
            if let error = error {
                _ = error
                self.fireCallback(nil)
                return
            }

            // Parse WebSocket opcode from metadata
            if let context,
               let wsMetadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata,
               wsMetadata.opcode == .text,
               let data,
               let rawString = String(data: data, encoding: .utf8) {
                let url = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
                self.fireCallback(url.isEmpty ? nil : url)
            }

            // Check if we should keep looping (connection still alive)
            switch conn.state {
            case .cancelled, .failed:
                self.fireCallback(nil)
            default:
                // Continue receiving
                self.receive(on: conn)
            }
        }
    }

    // MARK: - Helpers

    private func fireCallback(_ url: String?) {
        let callback = onURLChange
        DispatchQueue.main.async {
            callback?(url)
        }
    }
}

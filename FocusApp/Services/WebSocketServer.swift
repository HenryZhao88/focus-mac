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
            print("[WebSocketServer] Failed to create listener on port \(Constants.wsPort)")
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
            if case .failed(let error) = state {
                print("[WebSocketServer] Listener failed: \(error)")
            }
        }

        listener.start(queue: wsQueue)
    }

    func stop() {
        wsQueue.async { [weak self] in
            self?.connection?.cancel()
            self?.connection = nil
        }
        listener?.cancel()
        listener = nil
    }

    // MARK: - Receiving

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, context, isComplete, error in
            guard let self else { return }

            // Check connection state — fire nil callback on disconnect/failure
            if let error = error {
                print("[WebSocketServer] Receive error: \(error)")
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

            // Continue receiving
            self.receive(on: conn)
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

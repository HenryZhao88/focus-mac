// FocusApp/Services/BlocklistManager.swift
import Foundation
import Network

final class BlocklistManager {

    // MARK: - Domain blocklist

    static let blockedDomains: [String] = [
        // Video & streaming
        "youtube.com", "www.youtube.com", "youtu.be", "m.youtube.com",
        "netflix.com", "www.netflix.com",
        "hulu.com", "www.hulu.com",
        "disneyplus.com", "www.disneyplus.com",
        "twitch.tv", "www.twitch.tv", "m.twitch.tv",
        "primevideo.com", "www.primevideo.com",
        "max.com", "www.max.com",
        // Social media
        "instagram.com", "www.instagram.com",
        "tiktok.com", "www.tiktok.com",
        "twitter.com", "www.twitter.com", "x.com", "www.x.com",
        "facebook.com", "www.facebook.com", "m.facebook.com",
        "reddit.com", "www.reddit.com", "old.reddit.com",
        "snapchat.com", "www.snapchat.com",
        "pinterest.com", "www.pinterest.com",
        // Other distractions
        "9gag.com", "www.9gag.com",
        "tumblr.com", "www.tumblr.com",
        "buzzfeed.com", "www.buzzfeed.com",
    ]

    private static let hostsTag = "# FocusApp"
    private static let httpPort: NWEndpoint.Port = 8080

    private(set) var isActive = false
    private var httpListener: NWListener?
    private let serverQueue = DispatchQueue(label: "com.focusapp.blocklist")

    // MARK: - Public

    /// True if /etc/hosts has leftover Focus entries from a previous crash.
    /// Reading /etc/hosts requires no privileges.
    static func hasStaleEntries() -> Bool {
        (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8))?.contains(hostsTag) ?? false
    }

    /// Adds blocked domains to /etc/hosts and starts the local HTTP server.
    /// Shows a one-time admin password prompt. Returns false if the user cancels.
    @discardableResult
    func activate() -> Bool {
        // Clear stale entries first, then append fresh ones
        let echoLines = Self.blockedDomains
            .map { "echo '127.0.0.1 \($0) \(Self.hostsTag)' >> /etc/hosts" }
            .joined(separator: " && ")
        let command = [
            "sed -i '' '/\(Self.hostsTag)/d' /etc/hosts",
            echoLines,
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder",
        ].joined(separator: " && ")
        guard runPrivileged(bash: command) else { return false }
        isActive = true
        startHTTPServer()
        return true
    }

    /// Removes all Focus entries from /etc/hosts and stops the HTTP server.
    /// No-ops if blocking was never activated, so app quit without an active
    /// session never triggers a password prompt.
    /// macOS typically caches the admin auth for ~5 min after activate(),
    /// so the user won't see a second prompt if they stop the session soon after starting.
    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopHTTPServer()
        let command = [
            "sed -i '' '/\(Self.hostsTag)/d' /etc/hosts",
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder",
        ].joined(separator: " && ")
        runPrivileged(bash: command)
    }

    // MARK: - HTTP server (handles HTTP requests to blocked domains on port 8080)
    // Note: HTTPS sites (YouTube, Netflix, etc.) show a browser connection error
    // rather than this page — the overlay in the app is the primary blocked UX.

    private func startHTTPServer() {
        guard let listener = try? NWListener(using: .tcp, on: Self.httpPort) else { return }
        httpListener = listener
        listener.newConnectionHandler = { [weak self] conn in
            self?.handleConnection(conn)
        }
        listener.start(queue: serverQueue)
    }

    private func stopHTTPServer() {
        httpListener?.cancel()
        httpListener = nil
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: serverQueue)
        // Drain the incoming request, then respond with the blocked page
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in
            let body = Self.blockedPageHTML.data(using: .utf8)!
            let header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
            connection.send(content: header.data(using: .utf8)! + body, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    // MARK: - Privileged shell

    @discardableResult
    private func runPrivileged(bash command: String) -> Bool {
        // Escape double quotes for embedding in an AppleScript string literal.
        // Our commands only contain single-quoted shell strings, so no backslash
        // escaping is needed.
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: - Blocked page HTML

    private static let blockedPageHTML = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Blocked by Focus</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
          font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          background: #0a0a0a;
          color: #fff;
          height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          text-align: center;
        }
        .container { max-width: 480px; padding: 40px 24px; }
        .icon { font-size: 48px; margin-bottom: 24px; }
        h1 { font-size: 22px; font-weight: 700; margin-bottom: 12px; color: #ff6584; }
        p { font-size: 15px; line-height: 1.6; color: rgba(255,255,255,0.6); }
        .brand { color: rgba(255,255,255,0.9); font-weight: 600; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="icon">🚫</div>
        <h1>This site is blocked</h1>
        <p>
          <span class="brand">Focus</span> blocked this page because it doesn't relate
          to what you're currently working on. Finish your session first, then come back.
        </p>
      </div>
    </body>
    </html>
    """
}

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
        // Anime
        "hianime.to", "www.hianime.to",
        "aniwatch.to", "www.aniwatch.to",
        "anix.to", "www.anix.to",
        "aniwave.to", "www.aniwave.to",
        "anixstream.to", "www.anixstream.to",
        "9animetv.to", "www.9animetv.to",
        "aniwatchtv.to", "www.aniwatchtv.to",
    ]

    private static let hostsTag = "# FocusApp"

    private(set) var isActive = false

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
            "echo '' >> /etc/hosts",
            echoLines,
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder",
        ].joined(separator: " && ")
        guard runPrivileged(bash: command) else { return false }
        isActive = true
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
        let command = [
            "sed -i '' '/\(Self.hostsTag)/d' /etc/hosts",
            "dscacheutil -flushcache",
            "killall -HUP mDNSResponder",
        ].joined(separator: " && ")
        runPrivileged(bash: command)
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
}

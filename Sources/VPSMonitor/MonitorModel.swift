import Foundation
import SwiftUI

@MainActor
final class MonitorModel: ObservableObject {
    @Published var profile: ServerProfile
    @Published var password = ""
    @Published var connected = false
    @Published var busy = false
    @Published var refreshing = false
    @Published var snapshot: Snapshot?
    @Published var readings: [Reading] = []
    @Published var cpuUsage: Double?
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var identity: HostIdentity?
    @Published var paused = false
    @Published var interval: Double = 30 {
        didSet { UserDefaults.standard.set(interval, forKey: "refreshInterval") }
    }
    @Published var path = "~"
    @Published var listing: DirectoryListing?
    @Published var filesBusy = false
    @Published var fileError: String?
    @Published var preview: FilePreview?
    @Published var previewBusy = false
    private var timer: Task<Void, Never>?
    private var generation = UUID()
    private var activeProfile: ServerProfile?
    private var pendingConnection: SSHConnection?

    init() {
        let savedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        if [3.0, 5.0, 10.0, 30.0, 60.0].contains(savedInterval) { interval = savedInterval }
        if let data = UserDefaults.standard.data(forKey: "serverProfile"), let saved = try? JSONDecoder().decode(ServerProfile.self, from: data) {
            profile = saved
            if saved.rememberPassword { password = Keychain.read(saved.id) ?? "" }
        } else { profile = ServerProfile() }
    }

    var connection: SSHConnection { SSHConnection(profile: activeProfile ?? profile) }
    var serverLabel: String { let p = activeProfile ?? profile; return p.name.isEmpty ? p.host : p.name }
    var endpoint: String { let p = activeProfile ?? profile; return "\(p.user)@\(p.host):\(p.port)" }

    func connect() async {
        guard !busy else { return }
        error = nil; busy = true
        defer { busy = false }
        do {
            try profile.validate()
            let candidate = SSHConnection(profile: profile)
            guard FileManager.default.isExecutableFile(atPath: candidate.helper) else { throw MonitorError.message("SSH password helper is missing. Open the packaged VPS Monitor.app.") }
            // Reusing a profile after an endpoint change always requires new host verification.
            let saved = UserDefaults.standard.data(forKey: "serverProfile").flatMap { try? JSONDecoder().decode(ServerProfile.self, from: $0) }
            if saved?.host != profile.host || saved?.port != profile.port {
                profile.id = UUID().uuidString
            }
            let pending = SSHConnection(profile: profile)
            pendingConnection = pending
            if !FileManager.default.fileExists(atPath: pending.knownHosts.path) {
                identity = try await pending.scan()
            } else { try await establish(pending) }
        } catch { self.error = error.localizedDescription }
    }

    func acceptHost() async {
        guard let identity, let pending = pendingConnection else { return }
        self.identity = nil; busy = true
        defer { busy = false }
        do { try pending.trust(identity); try await establish(pending) }
        catch { self.error = error.localizedDescription }
    }

    private func establish(_ candidate: SSHConnection) async throws {
        if password.isEmpty { Keychain.delete(candidate.profile.id) }
        else { try Keychain.save(password, account: candidate.profile.id, helper: candidate.helper) }
        do {
            let data = try await candidate.script("monitor")
            let value = try JSONDecoder().decode(Snapshot.self, from: data)
            activeProfile = candidate.profile
            generation = UUID()
            snapshot = nil; cpuUsage = nil; readings = []; listing = nil; path = "~"; fileError = nil
            apply(value)
            connected = true; error = nil
            UserDefaults.standard.set(try JSONEncoder().encode(candidate.profile), forKey: "serverProfile")
            startTimer()
        } catch {
            if !candidate.profile.rememberPassword { Keychain.delete(candidate.profile.id) }
            throw error
        }
    }

    private func apply(_ next: Snapshot) {
        if let previous = snapshot {
            let total = next.cpuTotal - previous.cpuTotal
            let idle = next.cpuIdle - previous.cpuIdle
            if total > 0 { cpuUsage = min(100, max(0, 100 * Double(total - idle) / Double(total))) }
        }
        snapshot = next; lastUpdated = Date()
        if let cpuUsage {
            readings.append(Reading(date: Date(), cpu: cpuUsage, memory: 100 * Double(next.memoryUsed) / Double(max(1, next.memoryTotal))))
            readings = Array(readings.suffix(120))
        }
    }

    func refresh() async {
        guard connected, !refreshing else { return }
        let token = generation
        let ssh = connection
        refreshing = true
        defer { if generation == token { refreshing = false } }
        do {
            let value = try JSONDecoder().decode(Snapshot.self, from: await ssh.script("monitor"))
            guard generation == token else { return }
            apply(value); error = nil
        } catch { if generation == token { self.error = "Readings are stale. " + error.localizedDescription } }
    }

    func startTimer() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                guard let seconds = self?.interval else { return }
                do { try await Task.sleep(for: .seconds(seconds)) } catch { return }
                guard let self, self.connected else { return }
                if !self.paused { await self.refresh() }
            }
        }
    }

    func disconnect() {
        timer?.cancel(); timer = nil; generation = UUID()
        if let activeProfile, !activeProfile.rememberPassword { Keychain.delete(activeProfile.id) }
        activeProfile = nil; connected = false; refreshing = false; snapshot = nil
        readings = []; cpuUsage = nil; error = nil; listing = nil; preview = nil; filesBusy = false; previewBusy = false
    }

    func shutdown() {
        if let activeProfile, !activeProfile.rememberPassword { Keychain.delete(activeProfile.id) }
    }

    func forgetServer() {
        disconnect()
        Keychain.delete(profile.id)
        try? FileManager.default.removeItem(at: connection.knownHosts)
        UserDefaults.standard.removeObject(forKey: "serverProfile")
        profile = ServerProfile(); password = ""; identity = nil; pendingConnection = nil
    }

    func loadDirectory(_ target: String? = nil) async {
        guard connected, !filesBusy else { return }
        let token = generation, ssh = connection
        filesBusy = true; fileError = nil
        defer { if generation == token { filesBusy = false } }
        do {
            let encoded = Data((target ?? path).utf8).base64EncodedString()
            let value = try JSONDecoder().decode(DirectoryListing.self, from: await ssh.script("files", arguments: ["list", encoded]))
            guard generation == token else { return }
            listing = value; path = value.path
        } catch { if generation == token { fileError = error.localizedDescription } }
    }

    func open(_ file: RemoteFile) async {
        if file.directory { await loadDirectory(file.path); return }
        guard !previewBusy else { return }
        let token = generation, ssh = connection
        previewBusy = true; fileError = nil
        defer { if generation == token { previewBusy = false } }
        do {
            let value = try JSONDecoder().decode(FilePreview.self, from: await ssh.script("files", arguments: ["preview", Data(file.path.utf8).base64EncodedString()]))
            if generation == token { preview = value }
        } catch { if generation == token { fileError = error.localizedDescription } }
    }
}

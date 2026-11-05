import Foundation
import Security

struct ServerProfile: Codable, Equatable {
    var id = UUID().uuidString
    var name = "My VPS"
    var host = ""
    var port = "22"
    var user = "root"
    var rememberPassword = false

    func validate() throws {
        guard !host.isEmpty, host.range(of: "^[A-Za-z0-9][A-Za-z0-9.:%_-]*$", options: .regularExpression) != nil else {
            throw MonitorError.message("Enter a server IP address or hostname, without ssh:// or a username.")
        }
        guard let number = Int(port), (1...65535).contains(number) else { throw MonitorError.message("SSH port must be between 1 and 65535.") }
        guard user.range(of: "^[A-Za-z_][A-Za-z0-9_.-]*[$]?$", options: .regularExpression) != nil else {
            throw MonitorError.message("Enter a valid Linux username.")
        }
    }
}

enum MonitorError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

enum Keychain {
    static let service = "local.vpsmonitor.ssh"
    static func read(_ account: String) -> String? {
        var result: CFTypeRef?
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account, kSecReturnData as String: true]
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func save(_ password: String, account: String, helper: String) throws {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
        let data = Data(password.utf8)
        var status = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = q
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "VPS Monitor SSH password"
            var trusted: [SecTrustedApplication] = []
            for path in [Bundle.main.executablePath ?? CommandLine.arguments[0], helper] {
                var app: SecTrustedApplication?
                if SecTrustedApplicationCreateFromPath(path, &app) == errSecSuccess, let app { trusted.append(app) }
            }
            var access: SecAccess?
            if SecAccessCreate("VPS Monitor SSH password" as CFString, trusted as CFArray, &access) == errSecSuccess, let access {
                item[kSecAttrAccess as String] = access
            }
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw MonitorError.message("Could not save the password in Keychain (\(status)). Unlock your login keychain and try again.") }
    }
    static func delete(_ account: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] as CFDictionary)
    }
}

enum Shell {
    static func quote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    static func run(_ executable: String, _ arguments: [String], environment: [String: String] = [:], input: Data? = nil, timeout: TimeInterval = 25) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let folder = FileManager.default.temporaryDirectory.appendingPathComponent("vpsmonitor-" + UUID().uuidString)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                    defer { try? FileManager.default.removeItem(at: folder) }
                    let outURL = folder.appendingPathComponent("stdout"), errURL = folder.appendingPathComponent("stderr")
                    FileManager.default.createFile(atPath: outURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
                    FileManager.default.createFile(atPath: errURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
                    let out = try FileHandle(forWritingTo: outURL), err = try FileHandle(forWritingTo: errURL)
                    defer { try? out.close(); try? err.close() }
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
                    process.standardOutput = out; process.standardError = err
                    let pipe = Pipe()
                    process.standardInput = input == nil ? FileHandle.nullDevice : pipe
                    try process.run()
                    let timeoutWork = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)
                    if let input { try? pipe.fileHandleForWriting.write(contentsOf: input); try? pipe.fileHandleForWriting.close() }
                    process.waitUntilExit()
                    timeoutWork.cancel()
                    guard process.terminationStatus == 0 else {
                        let message = String(decoding: (try? Data(contentsOf: errURL)) ?? Data(), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                        throw MonitorError.message(message.isEmpty ? "The connection timed out or was closed. Check the host, SSH port, and network, then reconnect." : message)
                    }
                    continuation.resume(returning: try Data(contentsOf: outURL))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

struct HostIdentity {
    let keys: String
    let fingerprints: String
}

struct SSHConnection {
    let profile: ServerProfile
    var helper: String {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/VPSAskPass").path
        if FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        return URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().appendingPathComponent("VPSAskPass").path
    }
    static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("VPSMonitor")
    }
    var knownHosts: URL { Self.support.appendingPathComponent("known_hosts_" + profile.id) }

    static func knownHostsOption(for path: String) -> String {
        // -o values are parsed again by OpenSSH's config parser. Without inner
        // quotes, "Application Support" becomes two separate known-host files.
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "%", with: "%%")
        return "UserKnownHostsFile=\"" + escaped + "\""
    }

    func scan() async throws -> HostIdentity {
        let keys = try await Shell.run("/usr/bin/ssh-keyscan", ["-T", "8", "-p", profile.port, "-t", "ed25519,ecdsa,rsa", profile.host], timeout: 12)
        guard !keys.isEmpty else { throw MonitorError.message("No SSH host key received. Check the address and port, and confirm SSH is reachable.") }
        let fingerprints = try await Shell.run("/usr/bin/ssh-keygen", ["-l", "-E", "sha256", "-f", "-"], input: keys)
        return HostIdentity(keys: String(decoding: keys, as: UTF8.self), fingerprints: String(decoding: fingerprints, as: UTF8.self))
    }

    func trust(_ identity: HostIdentity) throws {
        try FileManager.default.createDirectory(at: Self.support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Data(identity.keys.utf8).write(to: knownHosts, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: knownHosts.path)
    }

    func execute(_ command: String, input: Data? = nil) async throws -> Data {
        guard FileManager.default.fileExists(atPath: knownHosts.path) else { throw MonitorError.message("Verify this server’s SSH fingerprint before connecting.") }
        return try await Shell.run("/usr/bin/ssh", ["-F", "/dev/null", "-T", "-p", profile.port,
            "-o", "ConnectTimeout=10", "-o", "ConnectionAttempts=1", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=2",
            "-o", "StrictHostKeyChecking=yes", "-o", Self.knownHostsOption(for: knownHosts.path),
            "-o", "GlobalKnownHostsFile=/dev/null", "-o", "NumberOfPasswordPrompts=1",
            "-o", "PreferredAuthentications=publickey,password,keyboard-interactive",
            "-o", "LogLevel=ERROR", profile.user + "@" + profile.host, command],
            environment: ["SSH_ASKPASS": helper, "SSH_ASKPASS_REQUIRE": "force", "DISPLAY": "vpsmonitor", "VPS_KEYCHAIN_ACCOUNT": profile.id], input: input)
    }

    func script(_ name: String, arguments: [String] = []) async throws -> Data {
        guard let url = Bundle.module.url(forResource: name, withExtension: "py", subdirectory: "Scripts") else {
            throw MonitorError.message("The app’s monitoring scripts are missing. Rebuild the application.")
        }
        return try await execute("python3 - " + arguments.map(Shell.quote).joined(separator: " "), input: Data(contentsOf: url))
    }
}

struct Service: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let state: String
    let substate: String
    let description: String
    static func expected(in group: String, services: [Service]) -> [Service] {
        var names = ["octane", "reverb", "queue", "scheduler"]
        if group == "CorGo" { names.insert("broadcast", at: 3) }
        let expected = names.map { group.lowercased() + "-" + $0 + ".service" }
        let actual = services.filter { $0.group == group }
        return actual + expected.filter { name in !actual.contains { $0.name == name } }.map {
            Service(name: $0, state: "not loaded", substate: "not-found", description: "Expected application service")
        }
    }
    var group: String {
        if name.hasPrefix("billo-") { return "Billo" }
        if name.hasPrefix("atlas-") { return "ATLAS" }
        if name.hasPrefix("corgo-") { return "CorGo" }
        return "System"
    }
}
struct RemoteProcess: Decodable, Identifiable {
    var id: Int { pid }
    let pid: Int
    let user: String
    let cpu: Double
    let memory: Double
    let rss: Int64
    let command: String
}
struct Snapshot: Decodable {
    let hostname: String
    let kernel: String
    let cores: Int
    let cpuTotal: Int64
    let cpuIdle: Int64
    let load: [Double]
    let memoryTotal: Int64
    let memoryAvailable: Int64
    let swapTotal: Int64
    let swapFree: Int64
    let diskTotal: Int64
    let diskUsed: Int64
    let diskFree: Int64
    let uptime: Double
    let services: [Service]
    let serviceError: String?
    let processes: [RemoteProcess]
    let processError: String?
    var memoryUsed: Int64 { max(0, memoryTotal - memoryAvailable) }
}
struct RemoteFile: Decodable, Identifiable {
    var id: String { path }
    let name: String
    let path: String
    let directory: Bool
    let symlink: Bool
    let size: Int64
    let modified: Double
    let permissions: String
    static func visible(_ entries: [RemoteFile], search: String, showHidden: Bool, sortOrder: [KeyPathComparator<RemoteFile>]) -> [RemoteFile] {
        entries.filter {
            (showHidden || !$0.name.hasPrefix(".")) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }.sorted(using: sortOrder)
    }
}
struct DirectoryListing: Decodable {
    let path: String
    let entries: [RemoteFile]
    let truncated: Bool
}
struct FilePreview: Decodable, Identifiable {
    var id: String { path }
    let path: String
    let content: String
    let truncated: Bool
}
struct Reading: Identifiable {
    let id = UUID()
    let date: Date
    let cpu: Double
    let memory: Double
}

func bytes(_ value: Int64) -> String { ByteCountFormatter.string(fromByteCount: value, countStyle: .binary) }

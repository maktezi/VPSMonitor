import Foundation
import Security

// OpenSSH calls this helper without a terminal. Only password prompts are answered.
let prompt = CommandLine.arguments.dropFirst().joined(separator: " ").lowercased()
guard prompt.contains("password"), let account = ProcessInfo.processInfo.environment["VPS_KEYCHAIN_ACCOUNT"] else { exit(1) }
let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: "local.vpsmonitor.ssh", kSecAttrAccount as String: account,
    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
var result: CFTypeRef?
guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data else { exit(1) }
FileHandle.standardOutput.write(data)
FileHandle.standardOutput.write(Data([10]))

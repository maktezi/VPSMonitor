import XCTest
@testable import VPSMonitor

final class CoreTests: XCTestCase {
    func testKnownHostsPathIsQuotedForOpenSSHConfigParser() async throws {
        let path = "/Users/demo/Library/Application Support/VPSMonitor/known_hosts_test"
        XCTAssertEqual(SSHConnection.knownHostsOption(for: path), "UserKnownHostsFile=\"" + path + "\"")

        // A legitimate path with the word "none" between spaces is a decisive
        // offline reproducer: an unquoted path is split into multiple files,
        // making the reserved "none" token invalid. No network is contacted.
        let trickyPath = "/tmp/Application none Support/known_hosts_test"
        do {
            _ = try await Shell.run("/usr/bin/ssh", ["-G", "-F", "/dev/null", "-o", "UserKnownHostsFile=" + trickyPath, "example.invalid"])
            XCTFail("The original unquoted option should fail config parsing")
        } catch { XCTAssertTrue(error.localizedDescription.contains("none")) }
        let result = try await Shell.run("/usr/bin/ssh", ["-G", "-F", "/dev/null", "-o", SSHConnection.knownHostsOption(for: trickyPath), "example.invalid"])
        XCTAssertTrue(String(decoding: result, as: UTF8.self).contains("userknownhostsfile " + trickyPath))
    }

    func testFileSortingPreservesFiltersAndStableIdentity() {
        let files = [
            RemoteFile(name: "zeta.txt", path: "/zeta.txt", directory: false, symlink: false, size: 10, modified: 300, permissions: "-rw-r--r--"),
            RemoteFile(name: "alpha", path: "/alpha", directory: true, symlink: false, size: 40, modified: 200, permissions: "drwxr-xr-x"),
            RemoteFile(name: "beta.txt", path: "/beta.txt", directory: false, symlink: false, size: 20, modified: 100, permissions: "-rw-r--r--"),
            RemoteFile(name: ".hidden", path: "/.hidden", directory: false, symlink: false, size: 5, modified: 50, permissions: "-rw-------")
        ]
        func visible(_ sort: KeyPathComparator<RemoteFile>, search: String = "", hidden: Bool = false) -> [String] {
            RemoteFile.visible(files, search: search, showHidden: hidden, sortOrder: [sort]).map(\.id)
        }
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.name)), ["/alpha", "/beta.txt", "/zeta.txt"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.name, order: .reverse)), ["/zeta.txt", "/beta.txt", "/alpha"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.size)), ["/zeta.txt", "/beta.txt", "/alpha"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.size, order: .reverse)), ["/alpha", "/beta.txt", "/zeta.txt"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.modified)), ["/beta.txt", "/alpha", "/zeta.txt"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.modified, order: .reverse)), ["/zeta.txt", "/alpha", "/beta.txt"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.name), search: ".TXT"), ["/beta.txt", "/zeta.txt"])
        XCTAssertEqual(visible(KeyPathComparator(\RemoteFile.name), hidden: true).first, "/.hidden")
    }
    func testConnectionValidationRejectsOptionsAndShellInput() throws {
        for host in ["-oProxyCommand=bad", "root@example.com", "ssh://example.com", "example.com; touch /tmp/bad", "a\nb", ""] {
            var profile = ServerProfile(); profile.host = host
            XCTAssertThrowsError(try profile.validate(), host)
        }
        for host in ["203.0.113.10", "example.com", "2001:db8::1", "demo-vps"] {
            var profile = ServerProfile(); profile.host = host
            XCTAssertNoThrow(try profile.validate())
        }
        var profile = ServerProfile(); profile.host = "example.com"; profile.port = "65536"
        XCTAssertThrowsError(try profile.validate())
        profile.port = "22"; profile.user = "root;id"
        XCTAssertThrowsError(try profile.validate())
    }

    func testRemoteShellQuotingPreservesLiteralInput() async throws {
        let value = "a'b $(id) `whoami` ; \"quoted\"\nsecond line"
        let data = try await Shell.run("/bin/sh", ["-c", "printf %s " + Shell.quote(value)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), value)
    }

    func testSubprocessReportsErrors() async {
        do {
            _ = try await Shell.run("/bin/sh", ["-c", "printf 'Permission denied' >&2; exit 3"])
            XCTFail("Expected command failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("Permission denied")) }
    }

    func testSubprocessTimeout() async {
        let start = Date()
        do {
            _ = try await Shell.run("/bin/sleep", ["10"], timeout: 0.1)
            XCTFail("Expected timeout")
        } catch { XCTAssertLessThan(Date().timeIntervalSince(start), 3) }
    }

    func testServiceGrouping() throws {
        let json = #"[{"name":"billo-queue.service","state":"active","substate":"running","description":"Billo queue"},{"name":"atlas-octane.service","state":"failed","substate":"failed","description":"Atlas"},{"name":"postgresql.service","state":"active","substate":"exited","description":"Postgres"}]"#
        let services = try JSONDecoder().decode([Service].self, from: Data(json.utf8))
        XCTAssertEqual(services.map(\.group), ["Billo", "ATLAS", "System"])
        XCTAssertEqual(services.last?.substate, "exited")
        let billo = Service.expected(in: "Billo", services: services)
        XCTAssertEqual(billo.count, 4)
        XCTAssertEqual(billo.filter { $0.state == "not loaded" }.count, 3)
        XCTAssertEqual(Service.expected(in: "CorGo", services: []).count, 5)
    }
}

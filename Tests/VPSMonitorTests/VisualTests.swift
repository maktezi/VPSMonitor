import XCTest
import SwiftUI
import AppKit
@testable import VPSMonitor

final class VisualTests: XCTestCase {
    @MainActor
    func testRenderNativeScreensWhenRequested() throws {
        guard let destination = ProcessInfo.processInfo.environment["VPS_RENDER_DIR"] else { throw XCTSkip("Set VPS_RENDER_DIR for native UI captures.") }
        _ = NSApplication.shared
        let model = MonitorModel()
        model.profile = ServerProfile()
        model.profile.name = "Demo VPS"
        model.profile.host = "203.0.113.10"
        try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
        try capture(ConnectionView().environmentObject(model), size: NSSize(width: 900, height: 760), name: "connection", destination: destination)
        let fixture: [String: Any] = [
            "hostname": "demo-vps", "kernel": "6.8.0-90-generic", "cores": 4,
            "cpuTotal": 2000, "cpuIdle": 1500, "load": [3.31, 1.41, 0.89],
            "memoryTotal": 8375186227, "memoryAvailable": 6227702579,
            "swapTotal": 0, "swapFree": 0, "diskTotal": 103079215104,
            "diskUsed": 9556302233, "diskFree": 93522912871, "uptime": 891234,
            "services": [
                ["name": "billo-octane.service", "state": "active", "substate": "running", "description": "Billo Octane"],
                ["name": "billo-queue.service", "state": "active", "substate": "running", "description": "Billo Queue"],
                ["name": "atlas-octane.service", "state": "active", "substate": "running", "description": "ATLAS Octane"],
                ["name": "corgo-octane.service", "state": "active", "substate": "running", "description": "CorGo Octane"],
                ["name": "postgresql.service", "state": "active", "substate": "exited", "description": "PostgreSQL"],
                ["name": "redis-server.service", "state": "active", "substate": "running", "description": "Redis"],
                ["name": "mysql.service", "state": "active", "substate": "running", "description": "MySQL"]
            ],
            "processes": [["pid": 1024, "user": "www-data", "cpu": 18.2, "memory": 4.2, "rss": 352321536, "command": "php"]]
        ]
        model.snapshot = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: fixture))
        model.connected = true
        model.cpuUsage = 26.4
        for i in 0..<24 {
            let date = Date().addingTimeInterval(Double(i - 24) * 5.0)
            let cpu = 18.0 + Double(i % 7) * 3.0
            let memory = 25.6 + Double(i % 4) * 0.2
            model.readings.append(Reading(date: date, cpu: cpu, memory: memory))
        }
        try capture(OverviewView().environmentObject(model), size: NSSize(width: 950, height: 780), name: "overview", destination: destination)
        try capture(ServicesView().environmentObject(model), size: NSSize(width: 950, height: 640), name: "services", destination: destination)
        try capture(ProcessesView().environmentObject(model), size: NSSize(width: 950, height: 640), name: "processes", destination: destination)
        try capture(ContentView().environmentObject(model), size: NSSize(width: 1180, height: 790), name: "window", destination: destination)
        try capture(ContentView().environmentObject(model), size: NSSize(width: 960, height: 640), name: "window-minimum", destination: destination)
        try capture(ContentView().environmentObject(model), size: NSSize(width: 1180, height: 790), name: "window-dark", destination: destination, scheme: .dark)
        model.listing = DirectoryListing(path: "/var/www", entries: [
            RemoteFile(name: "billo", path: "/var/www/billo", directory: true, symlink: false, size: 4096, modified: Date().timeIntervalSince1970, permissions: "drwxr-xr-x"),
            RemoteFile(name: "atlas", path: "/var/www/atlas", directory: true, symlink: false, size: 4096, modified: Date().timeIntervalSince1970, permissions: "drwxr-xr-x"),
            RemoteFile(name: "deploy.log", path: "/var/www/deploy.log", directory: false, symlink: false, size: 4096, modified: Date().timeIntervalSince1970, permissions: "-rw-r--r--")
        ], truncated: false)
        model.path = "/var/www"
        try capture(ContentView(section: .files).environmentObject(model), size: NSSize(width: 1180, height: 790), name: "files", destination: destination)
    }

    @MainActor
    private func capture<V: View>(_ view: V, size: NSSize, name: String, destination: String, scheme: ColorScheme = .light) throws {
        let host = NSHostingView(rootView: view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, scheme))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        host.frame = NSRect(origin: .zero, size: size)
        window.display()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.35))
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            XCTFail("Could not allocate a bitmap for \(name)"); return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Could not render \(name)"); return
        }
        try png.write(to: URL(fileURLWithPath: destination).appendingPathComponent(name + ".png"))
        XCTAssertGreaterThan(png.count, 5000)
        window.orderOut(nil)
    }
}

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
        var fixture: [String: Any] = [
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
        // Complete application groups and one unrelated failed unit exercise the reference layout.
        var demoServices = fixture["services"] as! [[String: String]]
        for group in ["billo", "atlas", "corgo"] {
            let units = group == "corgo" ? ["octane", "reverb", "queue", "broadcast", "scheduler"] : ["octane", "reverb", "queue", "scheduler"]
            for unit in units where !demoServices.contains(where: { $0["name"] == "\(group)-\(unit).service" }) {
                demoServices.append(["name": "\(group)-\(unit).service", "state": "active", "substate": "running", "description": "Demo application service"])
            }
        }
        demoServices.append(["name": "demo-backup.service", "state": "failed", "substate": "failed", "description": "Demo failed backup unit"])
        fixture["services"] = demoServices
        model.snapshot = try JSONDecoder().decode(Snapshot.self, from: JSONSerialization.data(withJSONObject: fixture))
        model.connected = true
        model.lastUpdated = Date().addingTimeInterval(-4)
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
        try capture(ContentView().environmentObject(model), size: NSSize(width: 1240, height: 960), name: "window", destination: destination)
        try capture(ContentView().environmentObject(model), size: NSSize(width: 960, height: 640), name: "window-minimum", destination: destination)
        try capture(ContentView().environmentObject(model), size: NSSize(width: 1240, height: 960), name: "window-dark", destination: destination, scheme: .dark)
        try capture(ServicesView(initialFilter: "Failed").environmentObject(model), size: NSSize(width: 950, height: 640), name: "services-failed", destination: destination)
        model.paused = true
        try capture(ContentView().environmentObject(model), size: NSSize(width: 960, height: 640), name: "window-paused", destination: destination)
        model.paused = false
        model.error = "Readings are stale. The SSH connection timed out. Retry to collect a new reading."
        model.profile.name = "Production application server with a long name"
        try capture(ContentView().environmentObject(model), size: NSSize(width: 960, height: 640), name: "window-stale", destination: destination, scheme: .dark)
        model.error = nil
        model.readings = []
        model.cpuUsage = nil
        try capture(OverviewView().environmentObject(model), size: NSSize(width: 745, height: 640), name: "overview-sampling", destination: destination)
        try capture(VStack {
            AppServiceRow(group: "Billo", services: [Service(name: "billo-queue.service", state: "failed", substate: "failed", description: "Queue")])
            Divider()
            StatusLabel(state: "failed")
            StatusLabel(state: "inactive")
            StatusLabel(state: "not loaded")
        }.padding(), size: NSSize(width: 700, height: 240), name: "service-states", destination: destination)
        model.profile.name = "Demo VPS"
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

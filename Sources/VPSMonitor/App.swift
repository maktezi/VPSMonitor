import SwiftUI
import AppKit

struct VPSMonitorApp: App {
    @StateObject private var model = MonitorModel()
    var body: some Scene {
        WindowGroup("VPS Monitor") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 960, minHeight: 640)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.shutdown() }
        }
        .defaultSize(width: 1240, height: 960)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Server") {
                Button("Refresh") { Task { await model.refresh() } }.keyboardShortcut("r").disabled(!model.connected)
                Button(model.paused ? "Resume Monitoring" : "Pause Monitoring") { model.paused.toggle() }.disabled(!model.connected)
                Divider()
                Button("Disconnect") { model.disconnect() }.disabled(!model.connected)
            }
        }
    }
}

@main
enum AppEntry {
    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            for name in ["monitor", "files"] {
                guard let url = Bundle.module.url(forResource: name, withExtension: "py", subdirectory: "Scripts"),
                      FileManager.default.isReadableFile(atPath: url.path) else {
                    fputs("Missing resource: \(name)\n", stderr); exit(1)
                }
            }
            guard FileManager.default.isExecutableFile(atPath: SSHConnection(profile: ServerProfile()).helper) else {
                fputs("Missing SSH helper\n", stderr); exit(1)
            }
            print("App resources and SSH helper verified.")
            return
        }
        VPSMonitorApp.main()
    }
}

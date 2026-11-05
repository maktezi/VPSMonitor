// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VPSMonitor",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "VPSMonitor", targets: ["VPSMonitor"]), .executable(name: "VPSAskPass", targets: ["VPSAskPass"])],
    targets: [
        .executableTarget(name: "VPSMonitor", resources: [.copy("Scripts")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "VPSAskPass", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "VPSMonitorTests", dependencies: ["VPSMonitor"])
    ]
)

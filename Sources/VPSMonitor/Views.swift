import SwiftUI
import Charts
import AppKit

enum Section: String, CaseIterable, Identifiable {
    case overview = "Overview", processes = "Processes", services = "Services", files = "Files"
    var id: String { rawValue }
    var tint: Color {
        switch self { case .overview: MonitorPalette.cpu; case .processes: MonitorPalette.memory; case .services: .orange; case .files: MonitorPalette.storage }
    }
    var symbol: String {
        switch self { case .overview: "chart.xyaxis.line"; case .processes: "cpu"; case .services: "slider.horizontal.3"; case .files: "folder" }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var section: Section? = .overview
    @State private var forgetConfirmation = false
    @State private var serviceFilter = "All"
    init(section: Section = .overview) { _section = State(initialValue: section) }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    Text(model.connected ? model.serverLabel : "VPS Monitor")
                        .font(.system(size: 17, weight: .semibold)).lineLimit(2)
                        .help(model.connected ? model.serverLabel : "VPS Monitor")
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Circle().fill(model.connected ? Color.green : Color.secondary).frame(width: 5, height: 5)
                        Text(connectionStatus).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24).padding(.top, 12)
                Divider().padding(.horizontal, 24).padding(.bottom, 18)
                VStack(spacing: 3) {
                    ForEach(Section.allCases) { item in
                        Button {
                            if item == .services { serviceFilter = "All" }
                            section = item
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 14, weight: .medium)).foregroundStyle(.white)
                                    .frame(width: 25, height: 25)
                                    .background(item.tint.gradient, in: RoundedRectangle(cornerRadius: 6))
                                Text(item.rawValue).font(.body.weight(section == item ? .semibold : .regular))
                                Spacer(minLength: 0)
                                if item == .services, failedServices > 0 {
                                    Circle().fill(.red).frame(width: 6, height: 6)
                                        .accessibilityLabel("\(failedServices) failed services")
                                }
                            }
                            .foregroundStyle(section == item ? .primary : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(section == item && model.connected ? Color.primary.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!model.connected)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                }.padding(.horizontal, 16)
                Spacer(minLength: 10)
                VStack(alignment: .leading, spacing: 12) {
                    if model.connected {
                        Text(model.endpoint).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                        Button("Disconnect", systemImage: "rectangle.portrait.and.arrow.right") { model.disconnect() }
                            .buttonStyle(.borderless)
                    } else {
                        Text("Your server, at a glance.").font(.caption).foregroundStyle(.secondary)
                        if !model.profile.host.isEmpty {
                            Button("Forget saved server", systemImage: "trash") { forgetConfirmation = true }.buttonStyle(.borderless)
                        }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.background(MonitorSurface.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 225, max: 300)
        } detail: {
            Group {
                if model.connected {
                    VStack(spacing: 0) {
                        if let error = model.error { ErrorBanner(message: error) { Task { await model.refresh() } } }
                        if model.paused { Label("Monitoring paused. Displaying the last readings.", systemImage: "pause.circle").font(.callout).padding(10).frame(maxWidth: .infinity).background(.orange.opacity(0.1)) }
                        switch section ?? .overview {
                        case .overview: OverviewView(showServices: {
                            serviceFilter = "All"; section = .services
                        }, reviewServices: {
                            serviceFilter = "Failed"; section = .services
                        })
                        case .processes: ProcessesView()
                        case .services: ServicesView(initialFilter: serviceFilter).id(serviceFilter)
                        case .files: FilesView()
                        }
                        Divider()
                        HStack {
                            if model.refreshing { ProgressView().controlSize(.mini); Text("Updating…") }
                            else if let updated = model.lastUpdated {
                                (Text("Updated \(updated.formatted(date: .omitted, time: .standard)) · ") + Text(updated, style: .relative) + Text(" ago"))
                            }
                            Spacer()
                            Text("SSH · Read-only")
                        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 9)
                    }
                } else { ConnectionView() }
            }
            .background(MonitorSurface.content)
            .toolbarBackground(MonitorSurface.content, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
            .navigationTitle(model.connected ? (section ?? .overview).rawValue : "Connect to your VPS")
            .toolbar {
                if model.connected {
                    ToolbarItemGroup {
                        Picker("Refresh interval", selection: $model.interval) {
                            Text("Every 3 seconds").tag(3.0)
                            Text("Every 5 seconds").tag(5.0)
                            Text("Every 10 seconds").tag(10.0)
                            Text("Every 30 seconds").tag(30.0)
                            Text("Every 60 seconds").tag(60.0)
                        }.frame(width: 155).onChange(of: model.interval) { model.startTimer() }
                        Button(model.paused ? "Resume" : "Pause", systemImage: model.paused ? "play.fill" : "pause.fill") { model.paused.toggle() }.labelStyle(.iconOnly).help(model.paused ? "Resume automatic refresh" : "Pause automatic refresh")
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }.labelStyle(.iconOnly).disabled(model.refreshing).help("Refresh now (⌘R)")
                    }
                }
            }
        }
        .sheet(isPresented: Binding(get: { model.identity != nil }, set: { if !$0 { model.identity = nil } })) { HostTrustView() }
        .sheet(item: $model.preview) { preview in PreviewView(preview: preview) }
        .confirmationDialog("Forget this server?", isPresented: $forgetConfirmation) {
            Button("Forget Server", role: .destructive) { model.forgetServer() }
        } message: { Text("This removes the saved connection, password, and trusted host key from this Mac.") }
    }
    private var failedServices: Int { model.snapshot?.services.filter { $0.state == "failed" }.count ?? 0 }
    private var connectionStatus: String {
        if !model.connected { return "Not connected" }
        if model.error != nil { return "Connected · readings stale" }
        if model.paused { return "Connected · paused" }
        return "Connected · auto-monitoring"
    }
}

private enum MonitorPalette {
    static let cpu = Color(red: 0.32, green: 0.65, blue: 1)
    static let memory = Color(red: 0.73, green: 0.51, blue: 0.96)
    static let storage = Color(red: 0.30, green: 0.79, blue: 0.82)
}

private enum MonitorSurface {
    static let content = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.075, alpha: 1) : NSColor(white: 0.99, alpha: 1)
    })
    static let sidebar = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.10, alpha: 1) : NSColor(white: 0.96, alpha: 1)
    })
}

struct ConnectionView: View {
    @EnvironmentObject private var model: MonitorModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "server.rack").font(.system(size: 40, weight: .light)).foregroundStyle(.tint).accessibilityHidden(true)
                    Text("A clearer view of your server.").font(.system(size: 29, weight: .semibold))
                    Text("Monitor resources, check services, and browse files through a secure SSH connection.")
                        .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Form {
                    SwiftUI.Section("Server") {
                        TextField("Server name", text: $model.profile.name, prompt: Text("My VPS"))
                        TextField("IP or hostname", text: $model.profile.host, prompt: Text("203.0.113.10"))
                            .autocorrectionDisabled()
                        TextField("SSH port", text: $model.profile.port)
                    }
                    SwiftUI.Section("Authentication") {
                        TextField("Username", text: $model.profile.user)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $model.password, prompt: Text("Or leave empty to use an SSH key"))
                        Toggle("Remember password in Keychain", isOn: $model.profile.rememberPassword)
                    }
                }.formStyle(.grouped).scrollDisabled(true).frame(height: 340)
                .disabled(model.busy)
                if let error = model.error {
                    Label { Text(error).textSelection(.enabled).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: "exclamationmark.triangle.fill") }
                        .foregroundStyle(.red).font(.callout)
                }
                HStack {
                    if model.busy { ProgressView().controlSize(.small); Text("Connecting…").foregroundStyle(.secondary) }
                    Spacer()
                    Button("Connect to Server") { Task { await model.connect() } }
                        .buttonStyle(.borderedProminent).controlSize(.large).keyboardShortcut(.defaultAction)
                        .disabled(model.busy || model.profile.host.isEmpty || model.profile.user.isEmpty)
                }
                Divider()
                Label("No monitoring agent required", systemImage: "checkmark.shield")
                    .font(.callout.weight(.medium))
                Text("Requires a Linux server with Python 3 and systemd. File browsing and monitoring use your SSH account’s permissions. Passwords stay in macOS Keychain for the session unless you choose to remember them.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: 510).padding(40).frame(maxWidth: .infinity)
        }
    }
}

struct HostTrustView: View {
    @EnvironmentObject private var model: MonitorModel
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Verify your server", systemImage: "lock.shield").font(.title2.weight(.semibold))
            Text("This is your first connection to \(model.profile.host). Compare these SSH fingerprints with the ones in your VPS provider’s console before trusting this server.")
                .fixedSize(horizontal: false, vertical: true)
            Text(model.identity?.fingerprints ?? "").font(.system(.caption, design: .monospaced))
                .textSelection(.enabled).padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            Text("Your password is sent only after you trust the key and SSH verifies the server.")
                .font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("Cancel", role: .cancel) { model.identity = nil }
                Spacer()
                Button("Trust and Connect") { Task { await model.acceptHost() } }.buttonStyle(.borderedProminent)
            }
        }.padding(28).frame(width: 620)
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            if let retry { Button("Retry", action: retry) }
        }.font(.callout).padding(12).background(.orange.opacity(0.1))
    }
}

struct OverviewView: View {
    @EnvironmentObject private var model: MonitorModel
    var showServices: (() -> Void)? = nil
    var reviewServices: (() -> Void)? = nil
    var body: some View {
        if let s = model.snapshot {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(s.hostname).font(.system(size: 30, weight: .semibold))
                                    .textSelection(.enabled).lineLimit(2)
                                Text("\(s.cores) CPU cores · Linux \(s.kernel)")
                                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                            Spacer(minLength: 16)
                            Label("Up \(uptime(s.uptime))", systemImage: "clock")
                                .font(.callout).foregroundStyle(.secondary).fixedSize()
                        }
                        if s.serviceError == nil {
                            let failed = s.services.filter { $0.state == "failed" }.count
                            if failed > 0 {
                                HStack(spacing: 12) {
                                    Circle().fill(.red).frame(width: 6, height: 6).accessibilityHidden(true)
                                    Text("\(failed) \(failed == 1 ? "service failed" : "services failed")").fontWeight(.semibold)
                                    Text("· \(failed == 1 ? "a systemd unit needs" : "systemd units need") attention")
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 8)
                                    if let reviewServices {
                                        Button(action: reviewServices) { HStack(spacing: 8) { Text("Review"); Image(systemName: "arrow.right") } }
                                            .buttonStyle(.plain).foregroundStyle(.red).fontWeight(.semibold)
                                    }
                                }.font(.callout).padding(15)
                                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.red.opacity(0.25)))
                            }
                        }
                        HStack(alignment: .top, spacing: 32) {
                            ResourceSummary(title: "CPU", value: model.cpuUsage.map { String(format: "%.1f%%", $0) } ?? "Sampling…", detail: "\(s.cores) cores · sampled between refreshes", fraction: model.cpuUsage.map { $0 / 100 }, tint: MonitorPalette.cpu)
                            Divider()
                            ResourceSummary(title: "Memory", value: percent(s.memoryUsed, s.memoryTotal), detail: "\(bytes(s.memoryUsed)) of \(bytes(s.memoryTotal)) · \(bytes(s.memoryAvailable)) available", fraction: Double(s.memoryUsed) / Double(max(1, s.memoryTotal)), tint: MonitorPalette.memory)
                            Divider()
                            ResourceSummary(title: "Storage", value: percent(s.diskUsed, s.diskTotal), detail: "\(bytes(s.diskUsed)) of \(bytes(s.diskTotal)) · \(bytes(s.diskFree)) free on /", fraction: Double(s.diskUsed) / Double(max(1, s.diskTotal)), tint: MonitorPalette.storage)
                        }.fixedSize(horizontal: false, vertical: true).padding(.vertical, 8)
                        Divider()
                        HStack(alignment: .top, spacing: 48) {
                            VStack(alignment: .leading, spacing: 14) {
                                HistoryChart(title: "CPU history", readings: model.readings, memory: false, tint: MonitorPalette.cpu)
                                Text("Load average  " + s.load.map { String(format: "%.2f", $0) }.joined(separator: " / ") + "  (1 / 5 / 15 min)")
                                    .help("Linux run queue averages over 1, 5, and 15 minutes.")
                            }
                            VStack(alignment: .leading, spacing: 14) {
                                HistoryChart(title: "Memory history", readings: model.readings, memory: true, tint: MonitorPalette.memory)
                                Text(s.swapTotal == 0 ? "Swap not configured" : "Swap: \(bytes(s.swapTotal - s.swapFree)) / \(bytes(s.swapTotal))")
                            }
                        }.font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        Divider()
                        HStack {
                            Text("Services").font(.headline)
                            Spacer()
                            if s.serviceError == nil {
                                (Text("\(s.services.filter { $0.state == "active" }.count)").foregroundColor(.green) + Text(" active  ·  ") + Text("\(s.services.filter { $0.state == "failed" }.count)").foregroundColor(s.services.contains { $0.state == "failed" } ? .red : .secondary) + Text(" failed"))
                                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                            }
                            if let showServices {
                                Button(action: showServices) { HStack(spacing: 6) { Text("View all"); Image(systemName: "chevron.right").font(.caption.weight(.semibold)) } }
                                    .buttonStyle(.plain).foregroundStyle(.tint).padding(.leading, 12)
                            }
                        }
                        if let error = s.serviceError { ErrorBanner(message: error) }
                        else if geometry.size.width >= 830 {
                            HStack(alignment: .top, spacing: 48) { applications(s); databases(s) }
                        } else {
                            VStack(alignment: .leading, spacing: 24) { applications(s); databases(s) }
                        }
                        Text("Inactive or missing preset services may be expected. Completed means active (exited); it does not confirm a running process.")
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }.padding(geometry.size.width >= 830 ? 36 : 24)
                }.background(MonitorSurface.content)
            }
        }
    }
    private func applications(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("APPLICATIONS").font(.caption.weight(.medium)).tracking(0.7).foregroundStyle(.secondary).padding(.bottom, 12)
            Divider()
            ForEach(["Billo", "ATLAS", "CorGo"], id: \.self) { group in
                AppServiceRow(group: group, services: Service.expected(in: group, services: s.services))
                Divider()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func databases(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("DATABASES & CACHE").font(.caption.weight(.medium)).tracking(0.7).foregroundStyle(.secondary).padding(.bottom, 12)
            Divider()
            ForEach(["postgresql.service", "mysql.service", "redis-server.service"], id: \.self) { name in
                let service = s.services.first { $0.name == name }
                HStack {
                    Text(name.replacingOccurrences(of: ".service", with: "")).fontWeight(.medium)
                    Spacer(minLength: 8)
                    DatabaseStatus(service: service)
                }.frame(minHeight: 43)
                Divider()
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private func percent(_ used: Int64, _ total: Int64) -> String {
        String(format: "%.1f%%", 100 * Double(used) / Double(max(1, total)))
    }
    private func uptime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        return minutes >= 1440 ? "\(minutes / 1440)d \((minutes % 1440) / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct DatabaseStatus: View {
    let service: Service?
    private var completed: Bool { service?.state == "active" && service?.substate == "exited" }
    private var running: Bool { service?.state == "active" && service?.substate == "running" }
    var body: some View {
        HStack(spacing: 7) {
            if completed { Circle().strokeBorder(.secondary, lineWidth: 1.5).frame(width: 5, height: 5) }
            else { Circle().fill(running ? Color.green : (service?.state == "failed" ? .red : .secondary)).frame(width: 5, height: 5) }
            Text(completed ? "Completed" : (running ? "Running" : (service?.state.capitalized ?? "Not loaded")))
        }.font(.callout).foregroundStyle(running ? Color.green : (service?.state == "failed" ? .red : .secondary))
            .help(service.map { "\($0.state) (\($0.substate))" } ?? "This service is not loaded")
    }
}

struct ResourceSummary: View {
    let title: String
    let value: String
    let detail: String
    let fraction: Double?
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Circle().fill(tint).frame(width: 5, height: 5).accessibilityHidden(true)
                Text(title.uppercased()).font(.caption.weight(.medium)).tracking(0.8).foregroundStyle(.secondary)
            }
            (Text(value.hasSuffix("%") ? String(value.dropLast()) : value).font(.system(size: 44, weight: .light)) + Text(value.hasSuffix("%") ? "%" : "").font(.system(size: 23, weight: .regular)).foregroundColor(.secondary))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            GeometryReader { geometry in
                Capsule().fill(Color.primary.opacity(0.09))
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint).frame(width: geometry.size.width * min(1, max(0, fraction ?? 0)))
                    }
            }.frame(height: 3)
                .accessibilityLabel(title + " usage")
                .accessibilityValue(fraction == nil ? "Waiting for next reading" : value)
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistoryChart: View {
    let title: String
    let readings: [Reading]
    let memory: Bool
    let tint: Color
    private var rangeLabel: String {
        guard let first = readings.first, let last = readings.last, readings.count > 1 else { return "Collecting history" }
        let seconds = max(1, Int(last.date.timeIntervalSince(first.date)))
        return seconds >= 60 ? "Last \(seconds / 60)m \(seconds % 60)s" : "Last \(seconds)s"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text(title).font(.headline).foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(rangeLabel).font(.caption).foregroundStyle(.secondary)
            }
            if readings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(.secondary)
                    Text("History appears after the next refresh.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 120)
            } else {
                Chart {
                    ForEach(readings) { reading in
                        AreaMark(x: .value("Time", reading.date), yStart: .value("Baseline", 0), yEnd: .value("Usage", memory ? reading.memory : reading.cpu))
                            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Time", reading.date), y: .value("Usage", memory ? reading.memory : reading.cpu))
                            .foregroundStyle(tint).lineStyle(StrokeStyle(lineWidth: 1.8)).interpolationMethod(.monotone)
                    }
                    if let last = readings.last {
                        PointMark(x: .value("Time", last.date), y: .value("Usage", memory ? last.memory : last.cpu))
                            .foregroundStyle(tint.opacity(0.2)).symbolSize(130)
                        PointMark(x: .value("Time", last.date), y: .value("Usage", memory ? last.memory : last.cpu))
                            .foregroundStyle(tint).symbolSize(25)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: value.as(Int.self) == 50 ? [2, 4] : []))
                        AxisValueLabel(anchor: .leading) { Text("\(value.as(Int.self) ?? 0)").font(.caption2).foregroundStyle(Color.primary.opacity(0.65)) }
                    }
                }
                .chartXAxis(.hidden)
                .chartPlotStyle { $0.padding(.trailing, 6) }
                .frame(height: 120)
                .accessibilityLabel(title + ", " + rangeLabel + ", " + (readings.last.map { String(format: "%.1f percent", memory ? $0.memory : $0.cpu) } ?? "no data"))
            }
        }.frame(maxWidth: .infinity)
    }
}

struct AppServiceRow: View {
    let group: String
    let services: [Service]
    @State private var expanded = false
    private var active: Int { services.filter { $0.state == "active" }.count }
    private var failed: Int { services.filter { $0.state == "failed" }.count }
    private var statusColor: Color { failed > 0 ? .red : (!services.isEmpty && active == services.count ? .green : .secondary) }
    var body: some View {
        VStack(spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 10) {
                    Circle().fill(statusColor).frame(width: 5, height: 5)
                    Text(group).fontWeight(.medium)
                    Spacer(minLength: 6)
                    Text(failed > 0 ? "\(failed) failed" : "\(services.count) services")
                        .font(.caption).foregroundStyle(failed > 0 ? Color.red : .secondary)
                    Text("\(active) / \(services.count)").font(.callout).monospacedDigit().foregroundStyle(.secondary).frame(minWidth: 45, alignment: .trailing)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(width: 12)
                }.frame(minHeight: 43).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(group), \(active) of \(services.count) active, \(failed) failed")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Show or hide individual services")
            if expanded {
                VStack(spacing: 10) {
                    ForEach(services) { service in
                        HStack(alignment: .firstTextBaseline) {
                            Text(service.name).font(.caption).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            StatusLabel(state: service.state).fixedSize()
                        }
                    }
                }.padding(.leading, 15).padding(.bottom, 14)
            }
        }
    }
}

struct StatusLabel: View {
    let state: String
    var color: Color { switch state { case "active": .green; case "failed": .red; case "activating", "deactivating", "reloading": .orange; default: .secondary } }
    var body: some View {
        Label(state, systemImage: state == "active" ? "checkmark.circle.fill" : (state == "failed" ? "xmark.circle.fill" : (state == "not loaded" ? "minus.circle" : "circle")))
            .foregroundStyle(color).font(.callout)
    }
}

struct ProcessesView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var search = ""
    @State private var sortOrder = [KeyPathComparator(\RemoteProcess.cpu, order: .reverse)]
    var processes: [RemoteProcess] {
        (model.snapshot?.processes ?? []).filter { search.isEmpty || $0.command.localizedCaseInsensitiveContains(search) || $0.user.localizedCaseInsensitiveContains(search) || String($0.pid).contains(search) }.sorted(using: sortOrder)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("\(processes.count) processes", systemImage: "cpu").foregroundStyle(.secondary).font(.callout)
                Spacer()
                TextField("Search processes", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
            }.padding(16)
            if let error = model.snapshot?.processError { ErrorBanner(message: error) }
            Table(processes, sortOrder: $sortOrder) {
                TableColumn("Process", value: \.command) { p in Text(p.command).fontWeight(.medium).textSelection(.enabled) }.width(min: 150, ideal: 230)
                TableColumn("PID", value: \.pid) { p in Text(String(p.pid)).monospacedDigit() }.width(65)
                TableColumn("User", value: \.user).width(min: 75, ideal: 100)
                TableColumn("CPU %", value: \.cpu) { p in Text(String(format: "%.1f", p.cpu)).monospacedDigit() }.width(75)
                TableColumn("Memory", value: \.rss) { p in Text(bytes(p.rss)).monospacedDigit() }.width(95)
                TableColumn("RAM %", value: \.memory) { p in Text(String(format: "%.1f", p.memory)).monospacedDigit() }.width(75)
            }.overlay { if processes.isEmpty { ContentUnavailableView("No matching processes", systemImage: "cpu", description: Text(search.isEmpty ? "No process data is available from this server." : "Try a different process name, user, or PID.")) } }
            Text("Top 250 processes by CPU. Click column headings to sort. CPU is the lifetime average reported by ps and can exceed 100% on multiple cores.")
                .font(.caption).foregroundStyle(.secondary).padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ServicesView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var search = ""
    @State private var filter = "All"
    @State private var sortOrder = [KeyPathComparator(\Service.name)]
    init(initialFilter: String = "All") { _filter = State(initialValue: initialFilter) }
    var services: [Service] {
        (model.snapshot?.services ?? []).filter { s in
            (search.isEmpty || (s.name + " " + s.description).localizedCaseInsensitiveContains(search)) &&
            (filter == "All" || (filter == "Applications" && s.group != "System") || (filter == "Active" && s.state == "active") || (filter == "Failed" && s.state == "failed") || (filter == "Needs attention" && s.state != "active"))
        }.sorted(using: sortOrder)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Show", selection: $filter) {
                    ForEach(["All", "Applications", "Active", "Failed", "Needs attention"], id: \.self) { Text($0) }
                }.frame(width: 210)
                Spacer()
                TextField("Search services", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
            }.padding(16)
            if let error = model.snapshot?.serviceError { ErrorBanner(message: error) }
            Table(services, sortOrder: $sortOrder) {
                TableColumn("Service", value: \.name) { s in Text(s.name).fontWeight(.medium).textSelection(.enabled) }.width(min: 170, ideal: 230)
                TableColumn("Status", value: \.state) { s in StatusLabel(state: s.state) }.width(110)
                TableColumn("Substate", value: \.substate).width(90)
                TableColumn("Description", value: \.description)
            }.overlay { if services.isEmpty { ContentUnavailableView("No matching services", systemImage: "gearshape.2", description: Text("Try a different filter or search.")) } }
            HStack {
                Text("\(services.count) of \(model.snapshot?.services.count ?? 0) loaded services")
                Spacer()
                Text("Inactive services may be expected. Active (exited) does not mean a process is running.")
            }.font(.caption).foregroundStyle(.secondary).padding(12)
        }
    }
}

struct FilesView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var selection: String?
    @State private var search = ""
    @State private var showHidden = false
    @State private var sortOrder = [KeyPathComparator(\RemoteFile.name)]
    var files: [RemoteFile] {
        RemoteFile.visible(model.listing?.entries ?? [], search: search, showHidden: showHidden, sortOrder: sortOrder)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Parent folder", systemImage: "arrow.up") { Task { await model.loadDirectory(((model.listing?.path ?? "/") as NSString).deletingLastPathComponent) } }
                    .labelStyle(.iconOnly).disabled(model.filesBusy || model.listing?.path == "/" || model.listing == nil).help("Go to parent folder")
                Button("Home folder", systemImage: "house") { Task { await model.loadDirectory("~") } }.labelStyle(.iconOnly).disabled(model.filesBusy).help("Go to home folder")
                TextField("Remote folder path", text: $model.path).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).onSubmit { Task { await model.loadDirectory() } }
                Button("Go") { Task { await model.loadDirectory() } }.disabled(model.filesBusy)
                if model.filesBusy || model.previewBusy { ProgressView().controlSize(.small) }
            }.padding(16)
            HStack {
                Toggle("Show hidden files", isOn: $showHidden).toggleStyle(.checkbox)
                Spacer()
                TextField("Filter this folder", text: $search).textFieldStyle(.roundedBorder).frame(width: 220)
            }.padding(.horizontal, 16).padding(.bottom, 12)
            if let error = model.fileError { ErrorBanner(message: error) { Task { await model.loadDirectory() } } }
            Table(files, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { file in
                    Label(file.name, systemImage: file.symlink ? "link" : (file.directory ? "folder.fill" : "doc.text"))
                        .foregroundStyle(file.directory ? Color.accentColor : .primary)
                        .contextMenu { Button(file.directory ? "Open Folder" : "Preview File") { Task { await model.open(file) } }; Button("Copy Path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(file.path, forType: .string) } }
                }.width(min: 190, ideal: 280)
                TableColumn("Size", value: \.size) { file in Text(file.directory ? "—" : bytes(file.size)).monospacedDigit() }.width(90)
                TableColumn("Modified", value: \.modified) { file in Text(Date(timeIntervalSince1970: file.modified), format: .dateTime.year().month().day().hour().minute()) }.width(165)
                TableColumn("Permissions", value: \.permissions) { file in Text(file.permissions).font(.system(.caption, design: .monospaced)) }.width(100)
            }
            .contextMenu(forSelectionType: String.self) { ids in
                if let id = ids.first, let file = files.first(where: { $0.id == id }) { Button(file.directory ? "Open Folder" : "Preview File") { Task { await model.open(file) } } }
            } primaryAction: { ids in
                if let id = ids.first, let file = files.first(where: { $0.id == id }) { Task { await model.open(file) } }
            }
            .overlay { if files.isEmpty && !model.filesBusy && model.fileError == nil { ContentUnavailableView("No files to show", systemImage: "folder", description: Text(search.isEmpty ? (showHidden ? "This folder is empty." : "This folder has no visible files. Try showing hidden files.") : "Try a different filename or clear the filter.")) } }
            HStack {
                Text("\(files.count) items" + ((model.listing?.truncated ?? false) ? " · First 10,000 entries only" : ""))
                Spacer()
                Text("Double-click to open. Text previews up to 256 KB.")
                Button("Open") { if let file = files.first(where: { $0.id == selection }) { Task { await model.open(file) } } }.disabled(selection == nil || model.filesBusy || model.previewBusy)
            }.font(.caption).foregroundStyle(.secondary).padding(12)
        }.task { if model.listing == nil { await model.loadDirectory() } }
        .onChange(of: model.listing?.path) { selection = nil }
    }
}

struct PreviewView: View {
    let preview: FilePreview
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label((preview.path as NSString).lastPathComponent, systemImage: "doc.text").font(.headline)
                Spacer()
                Button("Copy Text", systemImage: "doc.on.doc") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(preview.content, forType: .string) }
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }.padding(18)
            Text(preview.path).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled).padding(.horizontal, 18).padding(.bottom, 12)
            Divider()
            if preview.truncated { Label("Showing the first 256 KB of this file.", systemImage: "info.circle").font(.callout).padding(12) }
            ScrollView([.horizontal, .vertical]) {
                Text(preview.content.isEmpty ? "Empty file" : preview.content).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(18)
            }.background(Color(nsColor: .textBackgroundColor))
        }.frame(minWidth: 750, idealWidth: 850, minHeight: 520, idealHeight: 650)
    }
}

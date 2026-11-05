import SwiftUI
import Charts
import AppKit

enum Section: String, CaseIterable, Identifiable {
    case overview = "Overview", processes = "Processes", services = "Services", files = "Files"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .overview: "chart.xyaxis.line"; case .processes: "cpu"; case .services: "gearshape.2"; case .files: "folder" }
    }
}

struct ContentView: View {
    @EnvironmentObject private var model: MonitorModel
    @State private var section: Section? = .overview
    @State private var forgetConfirmation = false
    init(section: Section = .overview) { _section = State(initialValue: section) }
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "server.rack").font(.title2).foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.connected ? model.serverLabel : "VPS Monitor").font(.headline).lineLimit(1)
                        Label(model.connected ? "Connected" : "Not connected", systemImage: "circle.fill")
                            .font(.caption).foregroundStyle(model.connected ? .green : .secondary)
                    }
                    Spacer(minLength: 0)
                }.padding(18)
                VStack(spacing: 4) {
                    ForEach(Section.allCases) { item in
                        Button { section = item } label: {
                            Label(item.rawValue, systemImage: item.symbol)
                                .font(.body.weight(section == item ? .medium : .regular))
                                .foregroundStyle(model.connected ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10).padding(.vertical, 9)
                                .background(section == item && model.connected ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(!model.connected)
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                    }
                }.padding(.horizontal, 10).padding(.top, 6)
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
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }.navigationSplitViewColumnWidth(min: 190, ideal: 215, max: 280)
        } detail: {
            Group {
                if model.connected {
                    VStack(spacing: 0) {
                        if let error = model.error { ErrorBanner(message: error) { Task { await model.refresh() } } }
                        if model.paused { Label("Monitoring paused. Displaying the last readings.", systemImage: "pause.circle").font(.callout).padding(10).frame(maxWidth: .infinity).background(.orange.opacity(0.1)) }
                        switch section ?? .overview {
                        case .overview: OverviewView()
                        case .processes: ProcessesView()
                        case .services: ServicesView()
                        case .files: FilesView()
                        }
                        Divider()
                        HStack {
                            if model.refreshing { ProgressView().controlSize(.mini); Text("Updating…") }
                            else if let updated = model.lastUpdated { Text("Updated \(updated.formatted(date: .omitted, time: .standard))") }
                            Spacer()
                            Text("SSH · Read-only")
                            if let snapshot = model.snapshot { Text("Linux \(snapshot.kernel)").lineLimit(1) }
                        }.font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.vertical, 9)
                    }
                } else { ConnectionView() }
            }
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
                        Button(model.paused ? "Resume" : "Pause", systemImage: model.paused ? "play.fill" : "pause.fill") { model.paused.toggle() }.help(model.paused ? "Resume automatic refresh" : "Pause automatic refresh")
                        Button("Refresh", systemImage: "arrow.clockwise") { Task { await model.refresh() } }.disabled(model.refreshing).help("Refresh now (⌘R)")
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
                    TextField("Server name", text: $model.profile.name, prompt: Text("My VPS"))
                    TextField("IP or hostname", text: $model.profile.host, prompt: Text("203.0.113.10"))
                        .autocorrectionDisabled()
                    TextField("SSH port", text: $model.profile.port)
                    TextField("Username", text: $model.profile.user)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $model.password, prompt: Text("Or leave empty to use an SSH key"))
                    Toggle("Remember password in Keychain", isOn: $model.profile.rememberPassword)
                }.formStyle(.grouped).scrollDisabled(true).frame(height: 290)
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
    var body: some View {
        if let s = model.snapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(s.hostname).font(.title.weight(.semibold)).textSelection(.enabled)
                        Spacer()
                        Label("Up \(uptime(s.uptime))", systemImage: "clock").foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 24) {
                        ResourceSummary(title: "CPU", value: model.cpuUsage.map { String(format: "%.1f%%", $0) } ?? "Sampling…", detail: "\(s.cores) cores", fraction: (model.cpuUsage ?? 0) / 100, tint: .blue)
                        Divider()
                        ResourceSummary(title: "Memory", value: bytes(s.memoryUsed), detail: "of \(bytes(s.memoryTotal)) · \(bytes(s.memoryAvailable)) available", fraction: Double(s.memoryUsed) / Double(max(1, s.memoryTotal)), tint: .purple)
                        Divider()
                        ResourceSummary(title: "Storage", value: bytes(s.diskUsed), detail: "of \(bytes(s.diskTotal)) · \(bytes(s.diskFree)) free", fraction: Double(s.diskUsed) / Double(max(1, s.diskTotal)), tint: .teal)
                    }.fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack(alignment: .top, spacing: 28) {
                        HistoryChart(title: "CPU history", readings: model.readings, memory: false, tint: .blue)
                        HistoryChart(title: "Memory history", readings: model.readings, memory: true, tint: .purple)
                    }
                    HStack(spacing: 24) {
                        Label("Load (1 / 5 / 15 min): " + s.load.map { String(format: "%.2f", $0) }.joined(separator: " / "), systemImage: "waveform.path")
                        Spacer()
                        Text(s.swapTotal == 0 ? "Swap: not configured" : "Swap: \(bytes(s.swapTotal - s.swapFree)) / \(bytes(s.swapTotal))")
                    }.font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    Divider()
                    HStack {
                        Text("Application services").font(.headline)
                        Spacer()
                        Text("\(s.services.filter { $0.state == "active" }.count) active services in total").font(.caption).foregroundStyle(.secondary)
                    }
                    if let error = s.serviceError { ErrorBanner(message: error) }
                    else {
                        VStack(spacing: 0) {
                            ForEach(["Billo", "ATLAS", "CorGo"], id: \.self) { group in
                                AppServiceRow(group: group, services: Service.expected(in: group, services: s.services))
                                Divider()
                            }
                            ForEach(["postgresql.service", "mysql.service", "redis-server.service"], id: \.self) { name in
                                let service = s.services.first { $0.name == name }
                                HStack {
                                    Text(name.replacingOccurrences(of: ".service", with: "")).frame(width: 130, alignment: .leading)
                                    Spacer()
                                    StatusLabel(state: service?.state ?? "not loaded")
                                }.padding(.vertical, 10)
                            }
                        }
                    }
                    Text("CPU is measured between refreshes. Load is the Linux run queue average. Process CPU uses ps lifetime averages; PostgreSQL’s umbrella service may be active (exited).").font(.caption).foregroundStyle(.secondary)
                }.padding(24)
            }
        }
    }
    private func uptime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        return minutes >= 1440 ? "\(minutes / 1440)d \((minutes % 1440) / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }
}

struct ResourceSummary: View {
    let title: String
    let value: String
    let detail: String
    let fraction: Double
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.headline)
            Text(value).font(.system(size: 27, weight: .medium)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            ProgressView(value: min(1, max(0, fraction))).tint(tint).accessibilityLabel(title + " usage")
            Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HistoryChart: View {
    let title: String
    let readings: [Reading]
    let memory: Bool
    let tint: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            if readings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.xyaxis.line").font(.title2).foregroundStyle(.secondary)
                    Text("History appears after the next refresh.").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 150).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Chart(readings) { reading in
                    LineMark(x: .value("Time", reading.date), y: .value("Usage", memory ? reading.memory : reading.cpu))
                        .foregroundStyle(tint).lineStyle(StrokeStyle(lineWidth: 1.8))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(values: [0, 50, 100]) { value in AxisGridLine(); AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") } } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.hour().minute().second()) } }
                .frame(height: 150)
                .accessibilityLabel(title + ", " + (readings.last.map { String(format: "%.1f percent", memory ? $0.memory : $0.cpu) } ?? "no data"))
            }
        }.frame(maxWidth: .infinity)
    }
}

struct AppServiceRow: View {
    let group: String
    let services: [Service]
    var body: some View {
        HStack(alignment: .top) {
            Text(group).font(.body.weight(.medium)).frame(width: 100, alignment: .leading)
            Text(services.isEmpty ? "No loaded services found" : services.map { $0.name.replacingOccurrences(of: ".service", with: "").replacingOccurrences(of: group.lowercased() + "-", with: "") }.joined(separator: " · "))
                .font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            if !services.isEmpty {
                let count = services.filter { $0.state == "active" }.count
                Label("\(count)/\(services.count) active", systemImage: count == services.count ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.callout).foregroundStyle(count == services.count ? .green : .orange)
            }
        }.padding(.vertical, 12)
    }
}

struct StatusLabel: View {
    let state: String
    var color: Color { switch state { case "active": .green; case "failed": .red; case "activating", "deactivating", "reloading": .orange; default: .secondary } }
    var body: some View { Label(state, systemImage: state == "active" ? "checkmark.circle.fill" : (state == "failed" ? "xmark.circle.fill" : "circle")).foregroundStyle(color).font(.callout) }
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
                Text("\(processes.count) processes").foregroundStyle(.secondary)
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
            }.overlay { if processes.isEmpty { ContentUnavailableView.search(text: search) } }
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
    var services: [Service] {
        (model.snapshot?.services ?? []).filter { s in
            (search.isEmpty || (s.name + " " + s.description).localizedCaseInsensitiveContains(search)) &&
            (filter == "All" || (filter == "Applications" && s.group != "System") || (filter == "Active" && s.state == "active") || (filter == "Needs attention" && s.state != "active"))
        }.sorted(using: sortOrder)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Show", selection: $filter) {
                    ForEach(["All", "Applications", "Active", "Needs attention"], id: \.self) { Text($0) }
                }.frame(width: 210)
                Spacer()
                TextField("Search services", text: $search).textFieldStyle(.roundedBorder).frame(width: 240)
            }.padding(16)
            if let error = model.snapshot?.serviceError { ErrorBanner(message: error) }
            Table(services, sortOrder: $sortOrder) {
                TableColumn("Service", value: \.name) { s in Text(s.name).fontWeight(.medium).textSelection(.enabled) }.width(min: 170, ideal: 230)
                TableColumn("Status", value: \.state) { s in StatusLabel(state: s.state) }.width(110)
                TableColumn("State", value: \.substate).width(90)
                TableColumn("Description", value: \.description)
            }.overlay { if services.isEmpty { ContentUnavailableView("No matching services", systemImage: "gearshape.2", description: Text("Try a different filter or search.")) } }
            HStack {
                Text("\(services.count) loaded services")
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
            .overlay { if files.isEmpty && !model.filesBusy && model.fileError == nil { ContentUnavailableView("No files to show", systemImage: "folder", description: Text("This folder is empty or no files match your filter.")) } }
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

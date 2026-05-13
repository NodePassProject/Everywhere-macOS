//
//  ContentView.swift
//  Everywhere
//
//  Created by Argsment Limited on 5/2/26.
//

import NetworkExtension
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject private var tunnel = TunnelManager.shared
    @ObservedObject private var store = ConfigurationStore.shared
    @State private var scrolledCore: CoreType? = ConfigurationStore.shared.selectedCore
    @State private var activationBlocked = false
    @State private var fileImporting = false
    @State private var isDownloading = false
    @State private var importErrorMessage: String?
    @State private var pendingDelete: Configuration?

    var body: some View {
        rootView
            .toolbar {
                tunnelStatusItem
                tunnelToggleItem
                addConfigurationItem
            }
            .fileImporter(
                isPresented: $fileImporting,
                allowedContentTypes: [.json, .yaml, .text, .data, .item],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Tunnel is running", isPresented: $activationBlocked) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Stop the tunnel before switching the active configuration or deleting the active one.")
            }
            .alert(
                "Connection failed",
                isPresented: errorAlertBinding,
                presenting: tunnel.lastError
            ) { _ in
                Button("OK", role: .cancel) { tunnel.clearLastError() }
            } message: { message in
                Text(message)
            }
            .alert(
                "Import error",
                isPresented: importErrorBinding,
                presenting: importErrorMessage
            ) { _ in
                Button("OK", role: .cancel) {}
            } message: { msg in
                Text(msg)
            }
            .confirmationDialog(
                "Delete configuration?",
                isPresented: deleteDialogBinding,
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { config in
                Button("Delete \(config.name)", role: .destructive) {
                    delete(config)
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
    }

    @ViewBuilder
    private var rootView: some View {
        if #available(macOS 15.0, *) {
            mainContent.containerBackground(.regularMaterial, for: .window)
        } else {
            mainContent
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if showController {
            ControllerView()
        } else {
            corePager
        }
    }

    // yacd talks to the clash REST API, which Xray-core does not
    // expose, so we only show the bundled dashboard for sing-box and
    // mihomo.
    private var showController: Bool {
        tunnel.coreRunning && store.selectedCore != .xray
    }

    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var tunnelStatusItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack {
                statusIndicator
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .contentTransition(.identity)
            }
            .padding(.horizontal)
            .animation(.default, value: tunnel.status)
            .animation(.default, value: tunnel.isReady)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if tunnel.status.isTransitioning {
            ProgressView()
                .controlSize(.small)
        } else {
            Circle().fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    private var statusText: String {
        if !tunnel.isReady { return String(localized: "Loading") }
        switch tunnel.status {
        case .connected: return String(localized: "Connected")
        case .connecting: return String(localized: "Connecting")
        case .disconnecting: return String(localized: "Disconnecting")
        case .reasserting: return String(localized: "Reconnecting")
        case .disconnected: return String(localized: "Disconnected")
        case .invalid: return String(localized: "Not Configured")
        @unknown default: return String(localized: "Unknown")
        }
    }

    // Only consulted for steady states; transitioning swaps the dot
    // out for a `ProgressView` in `statusIndicator`.
    private var statusColor: Color {
        if !tunnel.isReady { return .secondary }
        switch tunnel.status {
        case .connected: return .green
        case .disconnected: return .red
        case .invalid: return .gray
        default: return .secondary
        }
    }

    @ToolbarContentBuilder
    private var tunnelToggleItem: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Button {
                toggleTunnel()
            } label: {
                Label(toggleTitle, systemImage: toggleIcon)
            }
            .disabled(toggleDisabled)
            .help(toggleTitle)
        }
    }
    
    @ToolbarContentBuilder
    private var addConfigurationItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if isDownloading {
                ProgressView().controlSize(.small)
            } else {
                Menu {
                    Button {
                        promptCreate()
                    } label: {
                        Label("New", systemImage: "plus")
                    }
                    Button {
                        fileImporting = true
                    } label: {
                        Label("Import from file", systemImage: "doc")
                    }
                    Button {
                        promptDownload()
                    } label: {
                        Label("Download from URL", systemImage: "arrow.down.circle")
                    }
                } label: {
                    Label("New", systemImage: "plus")
                }
            }
        }
    }

    private var toggleTitle: String {
        isTunnelOnOrConnecting
            ? String(localized: "Disconnect")
            : String(localized: "Connect")
    }

    private var toggleIcon: String {
        isTunnelOnOrConnecting ? "stop.fill" : "play.fill"
    }

    private var toggleDisabled: Bool {
        if !tunnel.isReady { return true }
        if tunnel.status.isTransitioning { return true }
        return store.active == nil
    }

    // Tunnel is "on" — i.e. running, becoming so, or fighting to stay
    // up. Drives the toggle's action label and icon; status text is
    // handled separately by `statusText`.
    private var isTunnelOnOrConnecting: Bool {
        switch tunnel.status {
        case .connected, .connecting, .reasserting: return true
        default: return false
        }
    }

    // MARK: - Core pager

    private var corePager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(CoreType.allCases) { core in
                    corePage(for: core).id(core)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledCore, anchor: .center)
        .scrollDisabled(tunnel.status.isActive)
        .safeAreaInset(edge: .bottom) { coreIndicator }
        .onChange(of: scrolledCore) { _, newCore in
            guard let newCore, newCore != store.selectedCore else { return }
            store.selectedCore = newCore
        }
        .onChange(of: store.selectedCore) { _, newCore in
            if scrolledCore != newCore { scrolledCore = newCore }
        }
    }

    private var coreIndicator: some View {
        HStack(spacing: 4) {
            ForEach(CoreType.allCases) { core in
                indicatorChip(for: core)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.separator.opacity(0.5)))
        .padding(.bottom, 12)
    }

    private func indicatorChip(for core: CoreType) -> some View {
        let isSelected = store.selectedCore == core
        return Button {
            scrolledCore = core
        } label: {
            HStack(spacing: 6) {
                Image(core.rawValue)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Text(core.displayName)
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, isSelected ? 12 : 8)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.25) : .clear)
            )
            .animation(.snappy, value: isSelected)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(tunnel.status.isActive && !isSelected)
        .help(core.displayName)
    }

    private func corePage(for core: CoreType) -> some View {
        HStack(spacing: 0) {
            brandingColumn(for: core)
                .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
            configurationColumn(for: core)
                .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
        }
    }

    private func brandingColumn(for core: CoreType) -> some View {
        VStack(spacing: 16) {
            Image(core.rawValue)
                .resizable()
                .interpolation(.high)
                .frame(width: 128, height: 128)
            Text(core.displayName)
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func configurationColumn(for core: CoreType) -> some View {
        let configs = store.getConfigurations(for: core)
        ScrollView {
            LazyVStack(spacing: 12) {
                if configs.isEmpty {
                    emptyPlaceholder
                } else {
                    ForEach(configs) { config in
                        ConfigCard(
                            config: config,
                            isActive: store.activeIDByCoreType[core] == config.id,
                            action: { activate(config) },
                            onRename: { promptRename(config) },
                            onDelete: { pendingDelete = config }
                        )
                    }
                }
            }
            .padding()
        }
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Configurations")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Actions

    private func activate(_ config: Configuration) {
        if tunnel.status.isActive,
           store.activeIDByCoreType[config.coreType] != config.id {
            activationBlocked = true
            return
        }
        store.setActive(config)
    }

    private func delete(_ config: Configuration) {
        defer { pendingDelete = nil }
        let isActiveForCore = store.activeIDByCoreType[config.coreType] == config.id
        if tunnel.status.isActive, isActiveForCore {
            activationBlocked = true
            return
        }
        store.delete(config)
    }

    private func toggleTunnel() {
        guard let active = store.active else { return }
        let shouldEnable = !isTunnelOnOrConnecting
        Task {
            await tunnel.setEnabled(shouldEnable, configuration: active)
        }
    }

    private func promptCreate() {
        let core = store.selectedCore
        NameInputAlert.present(
            title: String(localized: "New \(core.displayName) configuration"),
            message: String(localized: "Enter a name for the new configuration."),
            placeholder: String(localized: "Name")
        ) { name in
            store.create(name: name, type: core, content: core.defaultConfig)
        }
    }

    private func promptRename(_ config: Configuration) {
        NameInputAlert.present(
            title: String(localized: "Rename configuration"),
            initialValue: config.name
        ) { name in
            store.update(config, name: name)
        }
    }

    private func promptDownload() {
        let core = store.selectedCore
        URLInputAlert.present(
            title: String(localized: "Download \(core.displayName) configuration"),
            message: String(localized: "Enter a URL to download the configuration from.")
        ) { url in
            download(from: url, for: core)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        let core = store.selectedCore
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                store.create(name: derivedName(from: url), type: core, content: content)
            } catch {
                importErrorMessage = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
            }
        case .failure(let err):
            importErrorMessage = err.localizedDescription
        }
    }

    private func download(from url: URL, for core: CoreType) {
        isDownloading = true
        Task {
            defer { Task { @MainActor in isDownloading = false } }
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                    throw NSError(
                        domain: "EverywhereDownload",
                        code: http.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode)."]
                    )
                }
                guard let content = String(data: data, encoding: .utf8) else {
                    throw NSError(
                        domain: "EverywhereDownload",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Response is not valid UTF-8 text."]
                    )
                }
                store.create(name: derivedName(from: url), type: core, content: content)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }

    private func derivedName(from url: URL) -> String {
        let stripped = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stripped.isEmpty, stripped != "/" {
            return stripped
        }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return String(localized: "Imported Configuration")
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { tunnel.lastError != nil },
            set: { if !$0 { tunnel.clearLastError() } }
        )
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }
}

// MARK: - Config card

private struct ConfigCard: View {
    @ObservedObject var config: Configuration
    let isActive: Bool
    let action: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    openWindow(id: ConfigEditorWindow.windowID, value: config.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Edit")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var metadata: String {
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(config.content.utf8.count),
            countStyle: .file
        )
        let updated = Self.relativeFormatter.localizedString(
            for: config.updatedAt,
            relativeTo: .now
        )
        return "\(size) · \(updated)"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()
}

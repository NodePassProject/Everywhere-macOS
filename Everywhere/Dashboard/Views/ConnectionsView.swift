//
//  ConnectionsView.swift
//  Everywhere
//
//  Created by NodePassProject on 11/16/26.
//

import SwiftUI

struct ConnectionsView: View {
    @ObservedObject var model: ConnectionsModel
    let core: CoreType

    @State private var searchText = ""
    @State private var confirmsCloseAll = false
    @State private var selection: ConnectionInfo.ID?
    @State private var inspected: ConnectionInfo?
    @State private var showsInspector = false
    @State private var sortOrder = [KeyPathComparator(\ConnectionInfo.start, order: .reverse)]

    var body: some View {
        Group {
            if model.isSupported {
                table
            } else {
                FeatureUnavailableView(title: "Connections", systemImage: "arrow.left.arrow.right", core: core)
            }
        }
        .navigationTitle("Connections")
    }

    private var visible: [ConnectionInfo] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        var items = model.items
        if !query.isEmpty {
            items = items.filter { connection in
                connection.destination.localizedCaseInsensitiveContains(query)
                    || connection.chain.contains { $0.localizedCaseInsensitiveContains(query) }
                    || connection.ruleDescription.localizedCaseInsensitiveContains(query)
                    || connection.process.localizedCaseInsensitiveContains(query)
                    || connection.sourceIP.localizedCaseInsensitiveContains(query)
            }
        }
        return items.sorted(using: sortOrder + [KeyPathComparator(\ConnectionInfo.id)])
    }

    private var table: some View {
        let connections = visible
        return Table(connections, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Host", value: \.destination) { connection in
                HStack(spacing: 6) {
                    Text(verbatim: connection.destination)
                        .truncationMode(.middle)
                    Spacer(minLength: 0)
                    Text(verbatim: connection.network.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .help(connection.destination)
            }
            .width(min: 140, ideal: 180)
            TableColumn("Chain", value: \.chainDescription) { connection in
                Text(verbatim: connection.chainDescription)
                    .truncationMode(.head)
                    .foregroundStyle(.secondary)
                    .help(connection.chainDescription)
            }
            .width(min: 80, ideal: 124)
            TableColumn("Download", value: \.download) { connection in
                figure(connection.download, speed: connection.downloadSpeed)
            }
            .width(min: 70, ideal: 126)
            TableColumn("Upload", value: \.upload) { connection in
                figure(connection.upload, speed: connection.uploadSpeed)
            }
            .width(min: 70, ideal: 126)
            TableColumn("Started", value: \.start) { connection in
                Text(verbatim: DashboardFormat.clock.string(from: connection.start))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .width(74)
        }
        .contextMenu(forSelectionType: ConnectionInfo.ID.self) { ids in
            if let connection = connections.first(where: { ids.contains($0.id) }) {
                Button {
                    model.close(connection)
                } label: {
                    Label("Close Connection", systemImage: "xmark")
                }
            }
        } primaryAction: { _ in
            showsInspector = true
        }
        .overlay {
            if connections.isEmpty {
                DashboardPlaceholder(
                    systemImage: "arrow.left.arrow.right",
                    title: searchText.isEmpty ? "No active connections" : "No matching connections"
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            DashboardStatusBar {
                Text("\(connections.count) Active")
            }
        }
        .inspector(isPresented: $showsInspector) {
            Group {
                if let inspected {
                    ConnectionDetailView(model: model, id: inspected.id, snapshot: inspected)
                } else {
                    Text("No Selection")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .inspectorColumnWidth(min: 240, ideal: 280, max: 400)
        }
        .searchable(text: $searchText)
        .toolbar {
            DashboardToolbarSpacer()
            ToolbarItemGroup {
                Button {
                    model.isPaused.toggle()
                } label: {
                    Label(model.isPaused ? "Resume" : "Pause", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                }
                .help(model.isPaused ? "Resume" : "Pause")

                Button {
                    confirmsCloseAll = true
                } label: {
                    Label("Close All Connections", systemImage: "xmark.circle")
                }
                .disabled(model.items.isEmpty)
                .help("Close All Connections")

                Button {
                    showsInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.trailing")
                }
                .help("Inspector")
            }
        }
        .onChange(of: selection) { _, id in
            inspected = id.flatMap { id in model.items.first { $0.id == id } }
        }
        .confirmationDialog(
            "Close all connections?",
            isPresented: $confirmsCloseAll,
            titleVisibility: .visible
        ) {
            Button("Close All Connections", role: .destructive) { model.closeAll() }
        }
        .alert("Something went wrong", isPresented: actionErrorBinding, presenting: model.actionError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private func figure(_ total: Int64, speed: Int64) -> some View {
        Text(verbatim: "\(DashboardFormat.bytes(total)) · \(DashboardFormat.speed(Double(speed)))")
            .monospacedDigit()
            .foregroundStyle(.secondary)
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }
}

private extension ConnectionInfo {
    var chainDescription: String {
        chain.joined(separator: " → ")
    }
}

// MARK: - Detail

struct ConnectionDetailView: View {
    @ObservedObject var model: ConnectionsModel
    let id: String
    let snapshot: ConnectionInfo

    private var live: ConnectionInfo? {
        model.items.first { $0.id == id }
    }

    var body: some View {
        let connection = live ?? snapshot
        Form {
            Section {
                row("State") {
                    Text(live != nil ? "Active" : "Closed")
                        .foregroundStyle(live != nil ? Color.green : Color.secondary)
                }
                row("Started", verbatim: DashboardFormat.clock.string(from: connection.start))
                row("Duration", verbatim: DashboardFormat.duration(since: connection.start))
            }

            Section("Destination") {
                row("Host", verbatim: connection.host)
                row("Sniffed Host", verbatim: connection.sniffHost)
                row("IP Address", verbatim: connection.destinationIP)
                row("Port", verbatim: connection.destinationPort)
                row("Remote Address", verbatim: connection.remoteDestination)
                row("Network", verbatim: connection.network.uppercased())
            }

            Section("Source") {
                row("Address", verbatim: sourceAddress(connection))
                row("Inbound", verbatim: connection.inbound)
                row("Process", verbatim: connection.process)
                row("DNS Mode", verbatim: connection.dnsMode)
            }

            Section("Routing") {
                row("Rule", verbatim: connection.ruleDescription)
                row("Chain", verbatim: connection.chain.joined(separator: " → "))
            }

            Section("Traffic") {
                row("Downloaded", verbatim: DashboardFormat.bytes(connection.download))
                row("Uploaded", verbatim: DashboardFormat.bytes(connection.upload))
                if live != nil {
                    row("Download Speed", verbatim: DashboardFormat.speed(Double(connection.downloadSpeed)))
                    row("Upload Speed", verbatim: DashboardFormat.speed(Double(connection.uploadSpeed)))
                }
            }

            if let live {
                Section {
                    Button("Close Connection", role: .destructive) {
                        model.close(live)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func sourceAddress(_ connection: ConnectionInfo) -> String {
        guard !connection.sourceIP.isEmpty else { return "" }
        let host = connection.sourceIP.contains(":") ? "[\(connection.sourceIP)]" : connection.sourceIP
        return connection.sourcePort.isEmpty ? host : "\(host):\(connection.sourcePort)"
    }

    private func row<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        LabeledContent(title) {
            value()
                .multilineTextAlignment(.trailing)
        }
    }

    @ViewBuilder
    private func row(_ title: LocalizedStringKey, verbatim value: String) -> some View {
        if !value.isEmpty {
            row(title) {
                Text(verbatim: value)
                    .textSelection(.enabled)
            }
        }
    }
}

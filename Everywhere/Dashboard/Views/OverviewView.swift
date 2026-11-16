//
//  OverviewView.swift
//  Everywhere
//
//  Created by NodePassProject on 11/16/26.
//

import SwiftUI

struct OverviewView: View {
    @ObservedObject var model: OverviewModel
    let core: CoreType

    @ObservedObject private var tunnel = TunnelManager.shared
    @State private var showsOutboundTraffic = false

    var body: some View {
        Form {
            if case .failed(let message) = model.link {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Can't reach the core")
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                trafficCard
            }

            Section("Status") {
                coreRow
                if let started = tunnel.connectedDate {
                    LabeledRow("Uptime", systemImage: "clock") {
                        Text(started, style: .timer)
                            .monospacedDigit()
                    }
                }
                LabeledRow("Extension Memory", systemImage: "memorychip") {
                    if let runtime = model.runtime {
                        Text(verbatim: memoryDescription(runtime))
                            .monospacedDigit()
                    } else {
                        Text(verbatim: "—")
                    }
                }
                FeatureRow(feature: .connections, core: core, title: "Connections", systemImage: "arrow.left.arrow.right") {
                    LabeledRow("Connections", systemImage: "arrow.left.arrow.right") {
                        Text(verbatim: model.connectionCount.map(String.init) ?? "—")
                            .monospacedDigit()
                    }
                }
            }

            Section("Outbound Mode") {
                FeatureRow(feature: .outboundMode, core: core, title: "Outbound Mode", systemImage: "arrow.triangle.branch") {
                    modePicker
                }
            }

            Section("Outbound Traffic") {
                FeatureRow(feature: .outboundTraffic, core: core, title: "Per-Outbound Totals", systemImage: "chart.bar") {
                    outboundTraffic
                }
            }

            Section("Tools") {
                toolRow(.flushFakeIP, title: "Flush Fake-IP Cache", systemImage: "eraser", success: String(localized: "Fake-IP cache flushed."))
                toolRow(.flushDNSCache, title: "Flush DNS Cache", systemImage: "arrow.counterclockwise", success: String(localized: "DNS cache flushed."))
                toolRow(.updateGeoData, title: "Update GEO Databases", systemImage: "globe", success: String(localized: "GEO databases updated."))
                FeatureRow(feature: .dnsQuery, core: core, title: "DNS Query", systemImage: "magnifyingglass") {
                    NavigationLink {
                        DNSQueryView(model: model)
                    } label: {
                        Label("DNS Query", systemImage: "magnifyingglass")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Overview")
        .alert(
            model.notice?.isError == true ? "Something went wrong" : "Done",
            isPresented: noticeBinding,
            presenting: model.notice
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { notice in
            Text(notice.message)
        }
    }

    private var noticeBinding: Binding<Bool> {
        Binding(get: { model.notice != nil }, set: { if !$0 { model.notice = nil } })
    }

    // MARK: Traffic

    private var trafficCard: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                speedColumn(
                    title: "Upload",
                    systemImage: "arrow.up",
                    color: DashboardColor.upload,
                    rate: model.rate.up,
                    total: model.totals?.up
                )
                Spacer(minLength: 12)
                speedColumn(
                    title: "Download",
                    systemImage: "arrow.down",
                    color: DashboardColor.download,
                    rate: model.rate.down,
                    total: model.totals?.down
                )
            }
            TrafficChart(samples: model.history)
                .frame(height: 96)
        }
        .padding(.vertical, 6)
    }

    private func speedColumn(
        title: LocalizedStringKey,
        systemImage: String,
        color: Color,
        rate: Double,
        total: Int64?
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.medium))
                .foregroundStyle(color)
            Text(verbatim: DashboardFormat.speed(rate))
                .font(.title2.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let total {
                Text("Total \(DashboardFormat.bytes(total))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: Status

    private var coreRow: some View {
        LabeledContent {
            if let version = displayVersion {
                Text(verbatim: version)
                    .monospacedDigit()
            }
        } label: {
            Label {
                Text(verbatim: core.displayName)
            } icon: {
                Image(core.rawValue)
                    .interpolation(.high)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
            }
        }
    }

    private var displayVersion: String? {
        guard let version = model.version, !version.isEmpty else { return nil }
        switch core {
        case .mihomo where version == "1.10.0": return nil
        case .singbox where version == "unknown": return nil
        default: return version
        }
    }

    private func memoryDescription(_ runtime: ExtensionRuntime) -> String {
        let used = DashboardFormat.bytes(runtime.footprint)
        guard runtime.available > 0 else { return used }
        return "\(used) / \(DashboardFormat.bytes(runtime.footprint + runtime.available))"
    }

    // MARK: Mode

    @ViewBuilder
    private var modePicker: some View {
        if model.modes.isEmpty {
            LabeledRow("Outbound Mode", systemImage: "arrow.triangle.branch") {
                ProgressView()
                    .controlSize(.small)
            }
        } else {
            let selection = Binding(
                get: { model.mode ?? "" },
                set: { mode in Task { model.setMode(mode) } }
            )
            let picker = Picker(selection: selection) {
                ForEach(model.modes, id: \.self) { mode in
                    Text(verbatim: modeTitle(mode)).tag(mode)
                }
            } label: {
                Label("Outbound Mode", systemImage: "arrow.triangle.branch")
            }
            if model.modes.count <= 4 {
                picker.pickerStyle(.segmented)
            } else {
                picker.pickerStyle(.menu)
            }
        }
    }

    private func modeTitle(_ mode: String) -> String {
        switch mode.lowercased() {
        case "rule": return String(localized: "Rule")
        case "global": return String(localized: "Global")
        case "direct": return String(localized: "Direct")
        default: return mode
        }
    }

    // MARK: Outbound traffic

    @ViewBuilder
    private var outboundTraffic: some View {
        if model.outboundTraffic.isEmpty {
            Text("No traffic yet")
                .foregroundStyle(.secondary)
        } else {
            let visible = showsOutboundTraffic ? model.outboundTraffic : Array(model.outboundTraffic.prefix(5))
            ForEach(visible, id: \.tag) { entry in
                LabeledContent {
                    HStack(spacing: 12) {
                        Label {
                            Text(verbatim: DashboardFormat.bytes(entry.totals.up))
                        } icon: {
                            Image(systemName: "arrow.up").foregroundStyle(DashboardColor.upload)
                        }
                        Label {
                            Text(verbatim: DashboardFormat.bytes(entry.totals.down))
                        } icon: {
                            Image(systemName: "arrow.down").foregroundStyle(DashboardColor.download)
                        }
                    }
                    .labelStyle(TrailingIconLabelStyle())
                    .font(.callout.monospacedDigit())
                } label: {
                    Text(verbatim: entry.tag)
                        .lineLimit(1)
                }
            }
            if model.outboundTraffic.count > 5 {
                Button(showsOutboundTraffic ? "Show Less" : "Show All \(model.outboundTraffic.count)") {
                    showsOutboundTraffic.toggle()
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: Tools

    private func toolRow(
        _ feature: DashboardFeature,
        title: LocalizedStringKey,
        systemImage: String,
        success: String
    ) -> some View {
        FeatureRow(feature: feature, core: core, title: title, systemImage: systemImage) {
            LabeledContent {
                if model.busyTools.contains(feature) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button("Run") {
                        model.run(feature, success: success)
                    }
                }
            } label: {
                Label(title, systemImage: systemImage)
            }
        }
    }
}

private struct LabeledRow<Value: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let value: Value

    init(_ title: LocalizedStringKey, systemImage: String, @ViewBuilder value: () -> Value) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
    }

    var body: some View {
        LabeledContent {
            value
        } label: {
            Label(title, systemImage: systemImage)
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: LabelStyleConfiguration) -> some View {
        HStack(spacing: 3) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: - DNS query

struct DNSQueryView: View {
    let model: OverviewModel

    private static let recordTypes = ["A", "AAAA", "CNAME", "MX", "TXT", "NS", "HTTPS"]

    @State private var name = ""
    @State private var type = "A"
    @State private var answers: [DNSAnswer] = []
    @State private var message: String?
    @State private var isQuerying = false

    var body: some View {
        Form {
            Section {
                TextField("Domain Name", text: $name, prompt: Text(verbatim: "example.com"))
                    .autocorrectionDisabled()
                    .onSubmit(query)
                Picker("Record Type", selection: $type) {
                    ForEach(Self.recordTypes, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                LabeledContent {
                    if isQuerying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Button("Query", action: query)
                            .disabled(trimmedName.isEmpty)
                    }
                } label: {
                    EmptyView()
                }
            }

            if let message {
                Section {
                    Text(verbatim: message)
                        .foregroundStyle(.secondary)
                }
            }

            if !answers.isEmpty {
                Section("Answers") {
                    ForEach(answers) { answer in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: answer.data)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                            Text(verbatim: "\(answer.type) · TTL \(answer.ttl) · \(answer.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("DNS Query")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func query() {
        let name = trimmedName
        guard !name.isEmpty, !isQuerying else { return }
        isQuerying = true
        message = nil
        Task {
            defer { isQuerying = false }
            do {
                answers = try await model.queryDNS(name: name, type: type)
                message = answers.isEmpty ? String(localized: "No records.") : nil
            } catch {
                answers = []
                message = error.localizedDescription
            }
        }
    }
}

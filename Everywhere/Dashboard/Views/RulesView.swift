//
//  RulesView.swift
//  Everywhere
//
//  Created by NodePassProject on 11/16/26.
//

import SwiftUI

struct RulesView: View {
    @ObservedObject var model: RulesModel

    private enum Page: Hashable {
        case rules, providers
    }

    @State private var page: Page = .rules
    @State private var searchText = ""

    private var core: CoreType { model.core }

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $page) {
                Text("Rules").tag(Page.rules)
                Text("Providers").tag(Page.providers)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(12)

            Divider()

            switch page {
            case .rules: rules
            case .providers: providers
            }
        }
        .navigationTitle("Rules")
        .searchable(text: $searchText)
        .toolbar {
            DashboardToolbarSpacer()
            ToolbarItem {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r")
                .help("Refresh")
            }
        }
        .task { await model.refresh() }
        .alert("Something went wrong", isPresented: actionErrorBinding, presenting: model.actionError) { _ in
            Button("OK", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(get: { model.actionError != nil }, set: { if !$0 { model.actionError = nil } })
    }

    private var query: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    // MARK: Rules

    private var visibleRules: [RoutingRule] {
        guard !query.isEmpty else { return model.rules }
        return model.rules.filter {
            $0.payload.localizedCaseInsensitiveContains(query)
                || $0.type.localizedCaseInsensitiveContains(query)
                || $0.target.localizedCaseInsensitiveContains(query)
        }
    }

    @ViewBuilder
    private var rules: some View {
        if !model.isLoaded {
            placeholder {
                if let error = model.loadError {
                    DashboardPlaceholder(systemImage: "exclamationmark.triangle", title: "Can't load rules", message: error)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        } else if visibleRules.isEmpty {
            placeholder {
                DashboardPlaceholder(
                    systemImage: "arrow.triangle.branch",
                    title: query.isEmpty ? "No rules" : "No matching rules"
                )
            }
        } else {
            Table(visibleRules) {
                TableColumn(Text(verbatim: "#")) { rule in
                    Text(verbatim: String(rule.id + 1))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
                .width(44)
                TableColumn("Type") { rule in
                    Text(verbatim: rule.type)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 130)
                TableColumn("Payload") { rule in
                    Text(verbatim: rule.payload)
                        .textSelection(.enabled)
                        .help(rule.payload)
                }
                .width(min: 140, ideal: 320)
                TableColumn("Target") { rule in
                    Text(verbatim: rule.target)
                        .foregroundStyle(Color.accentColor)
                }
                .width(min: 80, ideal: 140)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                DashboardStatusBar {
                    Text("\(visibleRules.count) Rules")
                }
            }
        }
    }

    // MARK: Providers

    private var visibleProviders: [RuleProvider] {
        guard !query.isEmpty else { return model.providers }
        return model.providers.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private var providers: some View {
        if !DashboardFeature.ruleProviders.isAvailable(on: core) {
            placeholder {
                FeatureUnavailableView(title: "Rule Providers", systemImage: "shippingbox", core: core)
            }
        } else if visibleProviders.isEmpty {
            placeholder {
                DashboardPlaceholder(
                    systemImage: "shippingbox",
                    title: query.isEmpty ? "No rule providers" : "No matching providers"
                )
            }
        } else {
            List(visibleProviders) { provider in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: provider.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        Text(verbatim: [provider.behavior, provider.vehicleType, provider.format]
                            .filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            Text("\(provider.ruleCount) Rules")
                            if let updatedAt = provider.updatedAt {
                                Text(verbatim: "·")
                                Text("Updated \(DashboardFormat.relative(updatedAt))")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.busyProviders.contains(provider.name) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 24, height: 24)
                    } else if provider.vehicleType != "Inline" {
                        Button {
                            model.updateProvider(provider.name)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.borderless)
                        .help("Update")
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }

    private func placeholder<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

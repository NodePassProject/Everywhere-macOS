//
//  DashboardView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

enum DashboardPane: String, CaseIterable, Identifiable {
    case home, overview, proxies, connections, rules, logs

    static let dashboard: [DashboardPane] = [.overview, .proxies, .connections, .rules, .logs]

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .home: return "Home"
        case .overview: return "Overview"
        case .proxies: return "Proxies"
        case .connections: return "Connections"
        case .rules: return "Rules"
        case .logs: return "Logs"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .overview: return "speedometer"
        case .proxies: return "point.3.connected.trianglepath.dotted"
        case .connections: return "arrow.left.arrow.right"
        case .rules: return "arrow.triangle.branch"
        case .logs: return "doc.text"
        }
    }
}

struct DashboardView<Home: View>: View {
    @StateObject private var store: DashboardStore
    @State private var pane: DashboardPane = .overview
    private let home: Home

    @MainActor
    init(core: CoreType, configID: UUID?, @ViewBuilder home: () -> Home) {
        _store = StateObject(wrappedValue: DashboardStore(core: core, configID: configID))
        self.home = home()
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $pane) {
                row(.home)
                Section("Dashboard") {
                    ForEach(DashboardPane.dashboard) { row($0) }
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 240)
        } detail: {
            NavigationStack {
                detail
            }
            .id(pane)
        }
        .onAppear { store.start() }
        .onDisappear { store.stop() }
    }

    private func row(_ pane: DashboardPane) -> some View {
        Label(pane.title, systemImage: pane.systemImage)
            .tag(pane)
    }

    @ViewBuilder
    private var detail: some View {
        switch pane {
        case .home: home
        case .overview: OverviewView(model: store.overview, core: store.core)
        case .proxies: ProxiesView(model: store.proxies)
        case .connections: ConnectionsView(model: store.connections, core: store.core)
        case .rules: RulesView(model: store.rules)
        case .logs: LogsView(model: store.logs)
        }
    }
}

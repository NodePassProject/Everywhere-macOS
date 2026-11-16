//
//  GeneralSettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var tunnel = TunnelManager.shared
    @AppStorage(DashboardPreferences.testURLKey) private var testURL = ""
    @AppStorage(DashboardPreferences.closeOnSwitchKey) private var closesOnSwitch = true

    var body: some View {
        Form {
            Section("VPN") {
                Toggle("Always On", isOn: $appState.alwaysOnEnabled)
                    .disabled(tunnel.pendingReconnect)
            }

            Section {
                Toggle("Dashboard", isOn: $appState.dashboardEnabled)
                    .disabled(tunnel.pendingReconnect)
                TextField("Latency Test URL", text: $testURL, prompt: Text(verbatim: DelayTestOptions.defaultURL))
                    .autocorrectionDisabled()
                Toggle("Close Connections on Switch", isOn: $closesOnSwitch)
            }
        }
        .formStyle(.grouped)
        .onChange(of: appState.dashboardEnabled) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.alwaysOnEnabled) { _, enabled in
            Task { await tunnel.applyAlwaysOn(enabled) }
        }
    }
}

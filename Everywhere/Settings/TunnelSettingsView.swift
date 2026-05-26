//
//  TunnelSettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/17/26.
//

import SwiftUI

struct TunnelSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var tunnel = TunnelManager.shared

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $appState.alwaysOnEnabled) {
                    Label("Always On", systemImage: "bolt")
                }
            }

            Section {
                Toggle("Include All Networks", isOn: $appState.tunnelIncludeAllNetworks)
            }

            Section {
                Toggle("Include Local Networks", isOn: $appState.tunnelIncludeLocalNetworks)
                Toggle("Include APNs", isOn: $appState.tunnelIncludeAPNs)
                Toggle("Include Cellular Services", isOn: $appState.tunnelIncludeCellularServices)
            }
            .disabled(!appState.tunnelIncludeAllNetworks)
        }
        .formStyle(.grouped)
        .navigationTitle("Tunnel")
        .disabled(tunnel.pendingReconnect)
        .onChange(of: appState.alwaysOnEnabled) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.tunnelIncludeAllNetworks) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.tunnelIncludeLocalNetworks) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.tunnelIncludeAPNs) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.tunnelIncludeCellularServices) { _, _ in
            Task { await tunnel.reconnect() }
        }
    }
}

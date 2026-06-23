//
//  GeneralSettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 6/23/26.
//

import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var tunnel = TunnelManager.shared
    
    var body: some View {
        Form {
            Section("App") {
                Toggle("Use zashboard", isOn: $appState.useZashboardEnabled)
            }
            
            Section("VPN") {
                Toggle("Always On", isOn: $appState.alwaysOnEnabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Tunnel")
        .disabled(tunnel.pendingReconnect)
        .onChange(of: appState.useZashboardEnabled) { _, _ in
            Task { await tunnel.reconnect() }
        }
        .onChange(of: appState.alwaysOnEnabled) { _, _ in
            Task { await tunnel.applyAlwaysOn(appState.alwaysOnEnabled) }
        }
    }
}

//
//  TunnelSettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct TunnelSettingsView: View {
    private enum Page: Hashable {
        case general, ipv4, ipv6, dns, proxy
    }

    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var tunnel = TunnelManager.shared
    @State private var page: Page = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $page) {
                Text("General").tag(Page.general)
                Text("IPv4").tag(Page.ipv4)
                Text("IPv6").tag(Page.ipv6)
                Text("DNS").tag(Page.dns)
                Text("Proxy").tag(Page.proxy)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Form {
                switch page {
                case .general: general
                case .ipv4: TunnelIPv4Settings()
                case .ipv6: TunnelIPv6Settings()
                case .dns: TunnelDNSSettings()
                case .proxy: TunnelProxySettings()
                }
            }
            .formStyle(.grouped)
        }
        .disabled(tunnel.pendingReconnect)
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

    @ViewBuilder
    private var general: some View {
        Section {
            Toggle("Include All Networks", isOn: $appState.tunnelIncludeAllNetworks)
        }

        Section {
            Toggle("Include Local Networks", isOn: $appState.tunnelIncludeLocalNetworks)
            Toggle("Include APNs", isOn: $appState.tunnelIncludeAPNs)
            Toggle("Include Cellular Services", isOn: $appState.tunnelIncludeCellularServices)
        }
        .disabled(!appState.tunnelIncludeAllNetworks)

        Section("Network Settings") {
            SettingNumberField(
                title: "MTU",
                value: $appState.tunnelNetworkSettings.mtu,
                range: TunnelNetworkSettings.mtuRange
            )
            SettingTextField(
                title: "Remote Address",
                placeholder: TunnelNetworkSettings().remoteAddress,
                value: $appState.tunnelNetworkSettings.remoteAddress,
                validate: { IPNetwork.isAddress($0) }
            )
        }

        Section {
            Button("Reset to default") {
                appState.tunnelNetworkSettings = TunnelNetworkSettings()
            }
            .disabled(appState.tunnelNetworkSettings == TunnelNetworkSettings())
        }
    }
}

//
//  ContentView+Toolbar.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import NetworkExtension
import SwiftUI

extension ContentView {
    // MARK: - Status

    @ToolbarContentBuilder
    var tunnelStatusItem: some ToolbarContent {
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
    var statusIndicator: some View {
        if tunnel.status.isTransitioning {
            ProgressView()
                .controlSize(.small)
        } else {
            Circle().fill(statusColor)
                .frame(width: 8, height: 8)
        }
    }

    var statusText: String {
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
    var statusColor: Color {
        if !tunnel.isReady { return .secondary }
        switch tunnel.status {
        case .connected: return .green
        case .disconnected: return .red
        case .invalid: return .gray
        default: return .secondary
        }
    }

    // MARK: - Toggle

    @ToolbarContentBuilder
    var tunnelToggleItem: some ToolbarContent {
        ToolbarItem {
            Button {
                toggleTunnel()
            } label: {
                Label(toggleTitle, systemImage: toggleIcon)
            }
            .disabled(toggleDisabled)
            .help(toggleTitle)
        }
    }

    var toggleTitle: String {
        isTunnelOnOrConnecting
            ? String(localized: "Disconnect")
            : String(localized: "Connect")
    }

    var toggleIcon: String {
        isTunnelOnOrConnecting ? "stop.fill" : "play.fill"
    }

    var toggleDisabled: Bool {
        if !tunnel.isReady { return true }
        if tunnel.status.isTransitioning { return true }
        return store.active == nil
    }

    // Tunnel is "on" — i.e. running, becoming so, or fighting to stay
    // up. Drives the toggle's action label and icon; status text is
    // handled separately by `statusText`.
    var isTunnelOnOrConnecting: Bool {
        switch tunnel.status {
        case .connected, .connecting, .reasserting: return true
        default: return false
        }
    }
}

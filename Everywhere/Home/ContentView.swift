//
//  ContentView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import NetworkExtension
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var tunnel = TunnelManager.shared
    @ObservedObject var store = ConfigurationStore.shared
    @State var activationBlocked = false
    @State var fileImporting = false
    @State var isDownloading = false
    @State var importErrorMessage: String?
    @State var pendingDelete: Configuration?
    @State var importCore: CoreType?

    private var showDashboard: Bool {
        tunnel.coreRunning && store.selectedCore != .xray
    }

    var body: some View {
        rootView
            .toolbar {
                tunnelStatusItem
                tunnelToggleItem
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
        if showDashboard {
            DashboardView()
        } else {
            corePager
        }
    }
}

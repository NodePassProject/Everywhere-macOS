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
    @ObservedObject var appState = AppState.shared
    @State var activationBlocked = false
    @State var fileImporting = false
    @State var isDownloading = false
    @State var updatingIDs: Set<UUID> = []
    @State var importErrorMessage: String?
    @State var pendingDelete: Configuration?
    @State var importCore: CoreType?
    @State var namePrompt: NamePrompt?
    @State var nameInput = ""
    @State var downloadCore: CoreType?
    @State var urlInput = ""
    
    private var showDashboard: Bool {
        tunnel.coreRunning && store.selectedCore != .xray && appState.useZashboardEnabled
    }
    
    var body: some View {
        rootViewWithToolbar
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
            .alert(
                namePrompt?.title ?? "",
                isPresented: namePromptBinding,
                presenting: namePrompt
            ) { prompt in
                TextField("Name", text: $nameInput)
                Button("Save") { submitName(for: prompt) }
                Button("Cancel", role: .cancel) {}
            } message: { prompt in
                if let message = prompt.message {
                    Text(message)
                }
            }
            .alert(
                downloadCore.map { String(localized: "Subscribe to \($0.displayName) configuration") } ?? "",
                isPresented: downloadPromptBinding,
                presenting: downloadCore
            ) { core in
                TextField(String("https://"), text: $urlInput)
                Button("Subscribe") { submitDownload(for: core) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Enter a subscription URL.")
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
    private var rootViewWithToolbar: some View {
        rootView
            .toolbar {
                tunnelStatusItem
                tunnelToggleItem
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

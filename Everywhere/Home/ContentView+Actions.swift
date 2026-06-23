//
//  ContentView+Actions.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import NetworkExtension
import SwiftUI

extension ContentView {
    // MARK: - Configuration actions

    func activate(_ config: Configuration) {
        if tunnel.status.isActive,
           store.activeIDByCoreType[config.coreType] != config.id {
            activationBlocked = true
            return
        }
        store.setActive(config)
    }

    func delete(_ config: Configuration) {
        defer { pendingDelete = nil }
        let isActiveForCore = store.activeIDByCoreType[config.coreType] == config.id
        if tunnel.status.isActive, isActiveForCore {
            activationBlocked = true
            return
        }
        store.delete(config)
    }

    func toggleTunnel() {
        guard let active = store.active else { return }
        let shouldEnable = !isTunnelOnOrConnecting
        Task {
            await tunnel.setEnabled(shouldEnable, configuration: active)
        }
    }

    func promptCreate(for core: CoreType) {
        NameInputAlert.present(
            title: String(localized: "New \(core.displayName) configuration"),
            message: String(localized: "Enter a name for the new configuration."),
            placeholder: String(localized: "Name")
        ) { name in
            store.create(name: name, type: core, content: core.defaultConfig)
        }
    }

    func promptRename(_ config: Configuration) {
        NameInputAlert.present(
            title: String(localized: "Rename configuration"),
            initialValue: config.name
        ) { name in
            store.update(config, name: name)
        }
    }

    func promptDownload(for core: CoreType) {
        URLInputAlert.present(
            title: String(localized: "Subscribe to \(core.displayName) configuration"),
            message: String(localized: "Enter a subscription URL.")
        ) { url in
            download(from: url, for: core)
        }
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        let core = importCore ?? store.selectedCore
        importCore = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                store.create(name: extractRemarks(from: content, fallbackUrl: url), type: core, content: content)
            } catch {
                importErrorMessage = "Could not read \(url.lastPathComponent): \(error.localizedDescription)"
            }
        case .failure(let err):
            importErrorMessage = err.localizedDescription
        }
    }

    func download(from url: URL, for core: CoreType) {
        isDownloading = true
        Task {
            defer { Task { @MainActor in isDownloading = false } }
            do {
                let content = try await fetchConfig(from: url)
                let name = extractRemarks(from: content, fallbackUrl: url)
                store.create(name: name, type: core, content: content, sourceURL: url.absoluteString)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
    
    func updateSubscription(_ config: Configuration) {
        guard let raw = config.sourceURL, let url = URL(string: raw) else { return }
        isDownloading = true
        Task {
            defer { Task { @MainActor in isDownloading = false } }
            do {
                let content = try await fetchConfig(from: url)
                store.update(config, content: content)
            } catch {
                importErrorMessage = error.localizedDescription
            }
        }
    }
    
    func fetchConfig(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("Everywhere/1.0 Clash/1.11.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(
                domain: "EverywhereDownload",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned HTTP \(http.statusCode)."]
            )
        }
        guard let content = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "EverywhereDownload",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Response is not valid UTF-8 text."]
            )
        }
        return content
    }
    
    func extractRemarks(from content: String, fallbackUrl: URL) -> String {
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let remarks = json["remarks"] as? String,
           !remarks.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return remarks.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return derivedName(from: fallbackUrl)
    }

    func derivedName(from url: URL) -> String {
        let stripped = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !stripped.isEmpty, stripped != "/" {
            return stripped
        }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return String(localized: "Imported Configuration")
    }

    // MARK: - Alert / dialog bindings

    var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { tunnel.lastError != nil },
            set: { if !$0 { tunnel.clearLastError() } }
        )
    }

    var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )
    }

    var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }
}

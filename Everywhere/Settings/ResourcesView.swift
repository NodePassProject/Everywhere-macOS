//
//  ResourcesView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ResourcesView: View {
    @State private var selectedCore: CoreType = ConfigurationStore.shared.selectedCore
    @State private var nodes: [ResourceNode] = []
    @State private var selection: Set<URL> = []
    @State private var importing = false
    @State private var importTarget: URL?
    @State private var errorMessage: String?
    @State private var newFolderDir: URL?
    @State private var folderNameInput = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Core", selection: $selectedCore) {
                ForEach(CoreType.allCases) { core in
                    Text(core.displayName).tag(core)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            Table(nodes, children: \.children, selection: $selection) {
                TableColumn("Name") { node in
                    Label {
                        Text(node.name)
                    } icon: {
                        Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundStyle(node.isDirectory ? Color.accentColor : Color.secondary)
                    }
                }
                TableColumn("Size") { node in
                    Text(node.isDirectory ? "" : (node.entry.formattedSize ?? "—"))
                        .foregroundStyle(.secondary)
                }
                .width(min: 70, ideal: 90)
            }
            .contextMenu(forSelectionType: URL.self) { ids in
                if !ids.isEmpty {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting(Array(ids))
                    } label: {
                        Label("Show in Finder", systemImage: "finder")
                    }
                    Button(role: .destructive) {
                        delete(ids)
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .frame(minHeight: 160)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button {
                        importTarget = targetDirectory
                        importing = true
                    } label: {
                        Label("Import Files", systemImage: "square.and.arrow.down")
                    }
                    Button {
                        promptNewFolder()
                    } label: {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        delete(selection)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
                Text("New items are added to \(targetLabel).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
        }
        .navigationTitle("Resources")
        .fileImporter(
            isPresented: $importing,
            allowedContentTypes: [.data, .json, .yaml, .text, .xml, .item],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Resources error", isPresented: errorBinding, presenting: errorMessage) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
        .alert("New Folder", isPresented: newFolderBinding, presenting: newFolderDir) { dir in
            TextField("Name", text: $folderNameInput)
            Button("Save") { createFolder(in: dir) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Enter a name for the new folder.")
        }
        .onAppear {
            selectedCore = ConfigurationStore.shared.selectedCore
            reload()
        }
        .onChange(of: selectedCore) { _, _ in
            selection.removeAll()
            reload()
        }
    }

    // MARK: - Targeting
    
    private var targetDirectory: URL {
        let root = ResourcesStore.directory(for: selectedCore)
        guard selection.count == 1, let url = selection.first,
              let node = findNode(url, in: nodes) else { return root }
        return node.isDirectory ? node.entry.url : node.entry.url.deletingLastPathComponent()
    }
    
    private var targetLabel: String {
        let root = ResourcesStore.directory(for: selectedCore)
        let target = targetDirectory
        if target == root { return selectedCore.displayName }
        let rel = target.path.replacingOccurrences(of: root.path + "/", with: "")
        return "\(selectedCore.displayName)/\(rel)"
    }

    private var footerText: String {
        switch selectedCore {
        case .xray:
            return """
            Xray-core picks files up here via xray.location.asset (geoip.dat, geosite.dat) and xray.location.cert (PEMs).
            """
        case .singbox:
            return """
            sing-box resolves relative paths in your config (cache_file.path, geoip.path, geosite.path, rule_set[].path) here.
            """
        case .mihomo:
            return """
            mihomo's $HOME/.config/mihomo is overridden to this directory (cache.db, GeoIP.dat, GeoSite.dat, ASN.mmdb, etc).
            """
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var newFolderBinding: Binding<Bool> {
        Binding(
            get: { newFolderDir != nil },
            set: { if !$0 { newFolderDir = nil } }
        )
    }

    // MARK: - Tree

    private func reload() {
        do {
            nodes = try buildNodes(at: ResourcesStore.directory(for: selectedCore))
        } catch {
            errorMessage = error.localizedDescription
            nodes = []
        }
    }

    private func buildNodes(at url: URL) throws -> [ResourceNode] {
        try ResourcesStore.list(at: url).map { entry in
            if entry.kind == .directory {
                return ResourceNode(entry: entry, children: (try? buildNodes(at: entry.url)) ?? [])
            }
            return ResourceNode(entry: entry, children: nil)
        }
    }

    private func findNode(_ url: URL, in nodes: [ResourceNode]) -> ResourceNode? {
        for node in nodes {
            if node.id == url { return node }
            if let children = node.children, let hit = findNode(url, in: children) {
                return hit
            }
        }
        return nil
    }

    // MARK: - Actions

    private func delete(_ ids: Set<URL>) {
        let entries = ids.compactMap { findNode($0, in: nodes)?.entry }
        for entry in entries {
            do {
                try ResourcesStore.delete(entry)
            } catch {
                errorMessage = error.localizedDescription
                break
            }
        }
        selection.removeAll()
        reload()
    }

    private func promptNewFolder() {
        folderNameInput = ""
        newFolderDir = targetDirectory
    }

    private func createFolder(in dir: URL) {
        let trimmed = folderNameInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try ResourcesStore.createFolder(named: trimmed, in: dir)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        let dir = importTarget ?? ResourcesStore.directory(for: selectedCore)
        importTarget = nil
        switch result {
        case .success(let urls):
            for source in urls {
                do {
                    try ResourcesStore.importFile(from: source, into: dir)
                } catch {
                    errorMessage = "Could not import \(source.lastPathComponent): \(error.localizedDescription)"
                    break
                }
            }
            reload()
        case .failure(let err):
            errorMessage = err.localizedDescription
        }
    }
}

private struct ResourceNode: Identifiable {
    let entry: ResourceEntry
    var children: [ResourceNode]?

    var id: URL { entry.url }
    var name: String { entry.name }
    var isDirectory: Bool { entry.kind == .directory }
}

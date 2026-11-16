//
//  ConfigEditorScreen.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct ConfigEditorScreen: View {
    @ObservedObject var configuration: Configuration
    @ObservedObject private var store = ConfigurationStore.shared
    @State private var draft: String
    @State private var revision = 0

    init(configuration: Configuration) {
        self._configuration = ObservedObject(wrappedValue: configuration)
        self._draft = State(initialValue: configuration.content)
    }

    var body: some View {
        ConfigEditorView(text: draftBinding, language: configuration.coreType.configLanguage)
            .id(revision)
            .navigationTitle(configuration.name.isEmpty ? "Configuration" : configuration.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            store.update(configuration, content: configuration.coreType.defaultConfig)
                        } label: {
                            Label("Reset to default", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                }
            }
            .onChange(of: configuration.content) { _, content in
                guard content != draft else { return }
                draft = content
                revision += 1
            }
    }

    private var draftBinding: Binding<String> {
        Binding(
            get: { draft },
            set: { newValue in
                draft = newValue
                store.update(configuration, content: newValue)
            }
        )
    }
}

struct ConfigEditorWindow: View {
    @ObservedObject private var store = ConfigurationStore.shared
    let configurationID: UUID?

    var body: some View {
        NavigationStack {
            if let config = resolvedConfiguration {
                ConfigEditorScreen(configuration: config)
            } else {
                ContentUnavailableView(
                    "Configuration not found",
                    systemImage: "doc.badge.ellipsis"
                )
            }
        }
        .frame(minWidth: 600, minHeight: 480)
    }

    private var resolvedConfiguration: Configuration? {
        guard let configurationID else { return nil }
        return store.configurations.first { $0.id == configurationID }
    }
}

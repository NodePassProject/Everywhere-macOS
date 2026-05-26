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

    init(configuration: Configuration) {
        self._configuration = ObservedObject(wrappedValue: configuration)
        self._draft = State(initialValue: configuration.content)
    }

    var body: some View {
        ConfigEditorView(text: draftBinding, language: configuration.coreType.configLanguage)
            .id(configuration.id)
            .navigationTitle(configuration.name.isEmpty ? "Configuration" : configuration.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            draft = configuration.coreType.defaultConfig
                            store.update(configuration, content: draft)
                        } label: {
                            Label("Reset to default", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis")
                    }
                }
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

// Standalone window that hosts `ConfigEditorScreen` for a configuration
// looked up by UUID. Used as a `WindowGroup` payload so each
// configuration can be edited in its own window.
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

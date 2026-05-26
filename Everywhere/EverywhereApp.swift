//
//  EverywhereApp.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

enum WindowID: String {
    case configEditor = "config-editor"
    case acknowledgements = "acknowledgements"
}

@main
struct EverywhereApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(before: .help) {
                AcknowledgementsMenuItem()
            }
        }

        WindowGroup(
            "Edit Configuration",
            id: WindowID.configEditor.rawValue,
            for: UUID.self
        ) { $configurationID in
            ConfigEditorWindow(configurationID: configurationID)
        }
        .defaultSize(width: 800, height: 600)
        .commandsRemoved()

        Window("Acknowledgements", id: WindowID.acknowledgements.rawValue) {
            AcknowledgementView()
        }
        .defaultSize(width: 600, height: 480)
        .commandsRemoved()

        Settings {
            SettingsView()
        }
    }
}

private struct AcknowledgementsMenuItem: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button {
            openWindow(id: WindowID.acknowledgements.rawValue)
        } label: {
            Label("Acknowledgements", systemImage: "heart")
        }
    }
}

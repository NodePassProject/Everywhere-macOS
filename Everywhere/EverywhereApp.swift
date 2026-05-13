//
//  EverywhereApp.swift
//  Everywhere
//
//  Created by Argsment Limited on 5/2/26.
//

import SwiftUI

@main
struct EverywhereApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        WindowGroup(
            "Edit Configuration",
            id: ConfigEditorWindow.windowID,
            for: UUID.self
        ) { $configurationID in
            ConfigEditorWindow(configurationID: configurationID)
        }
        .defaultSize(width: 800, height: 600)
        .commandsRemoved()

        Settings {
            SettingsView()
        }
    }
}

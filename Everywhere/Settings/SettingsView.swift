//
//  SettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

enum SettingsTab: String {
    case general, tunnel, resources

    static let key = "settings.tab"

    static func select(_ tab: SettingsTab) {
        UserDefaults.standard.set(tab.rawValue, forKey: key)
    }
}

struct SettingsView: View {
    @AppStorage(SettingsTab.key) private var tab: SettingsTab = .general

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general)
            TunnelSettingsView()
                .tabItem { Label("Tunnel", systemImage: "shield") }
                .tag(SettingsTab.tunnel)
            ResourcesView()
                .tabItem { Label("Resources", systemImage: "folder") }
                .tag(SettingsTab.resources)
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

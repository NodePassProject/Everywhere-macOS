//
//  SettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            TunnelSettingsView()
                .tabItem { Label("Tunnel", systemImage: "shield") }
            DNSSettingsView()
                .tabItem { Label("DNS", systemImage: "network") }
            ResourcesView()
                .tabItem { Label("Resources", systemImage: "folder") }
        }
        .frame(minWidth: 520, minHeight: 380)
    }
}

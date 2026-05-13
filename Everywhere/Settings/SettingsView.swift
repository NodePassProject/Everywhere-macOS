//
//  SettingsView.swift
//  Everywhere
//
//  Created by Argsment Limited on 5/2/26.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            DNSSettingsView()
                .tabItem { Label("DNS", systemImage: "network") }
            ResourcesView()
                .tabItem { Label("Resources", systemImage: "folder") }
        }
        .frame(minWidth: 520, minHeight: 380)
    }
}

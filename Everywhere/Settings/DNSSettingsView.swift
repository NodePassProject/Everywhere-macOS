//
//  DNSSettingsView.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import Network
import SwiftUI

private struct DNSServerDraft: Identifiable, Equatable {
    let id = UUID()
    var value: String
}

struct DNSSettingsView: View {
    @ObservedObject private var appState = AppState.shared
    @State private var serverDrafts: [DNSServerDraft] = []
    @State private var isEditing = false

    var body: some View {
        Form {
            Section("DNS Servers") {
                ForEach($serverDrafts) { $draft in
                    HStack {
                        if isEditing {
                            TextField("Address", text: $draft.value)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        } else {
                            Text(draft.value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if isEditing {
                            Button(role: .destructive) {
                                remove(draft.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if isEditing {
                    Button {
                        serverDrafts.append(DNSServerDraft(value: ""))
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            Section {
                HStack {
                    Button(isEditing ? String(localized: "Done") : String(localized: "Edit")) {
                        if isEditing {
                            save()
                        }
                        isEditing.toggle()
                    }
                    Button("Reset to default") {
                        reset()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("DNS")
        .onAppear { loadInitial() }
    }

    private func loadInitial() {
        serverDrafts = appState.dnsServers.map { DNSServerDraft(value: $0) }
    }

    private func remove(_ id: UUID) {
        serverDrafts.removeAll { $0.id == id }
    }

    private func save() {
        serverDrafts = serverDrafts
            .filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let servers = serverDrafts
            .map { $0.value.trimmingCharacters(in: .whitespacesAndNewlines) }
        appState.dnsServers = servers
    }

    private func reset() {
        appState.dnsServers = EVCore.defaultDNSServers
        loadInitial()
    }

    private func isValid(_ raw: String) -> Bool {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return false }
        return IPv4Address(s) != nil || IPv6Address(s) != nil
    }
}

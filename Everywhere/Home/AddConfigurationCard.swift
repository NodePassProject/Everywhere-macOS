//
//  AddConfigurationCard.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct AddConfigurationCard: View {
    let isDownloading: Bool
    let isDisabled: Bool
    let onNew: () -> Void
    let onImport: () -> Void
    let onDownload: () -> Void

    var body: some View {
        if isDownloading {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Downloading…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
        } else {
            Menu {
                Button(action: onNew) {
                    Label("New", systemImage: "plus")
                }
                Button(action: onImport) {
                    Label("Import from file", systemImage: "doc")
                }
                Button(action: onDownload) {
                    Label("Subscribe", systemImage: "link")
                }
            } label: {
                Label("Add Configuration", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.quaternary.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                Color.accentColor.opacity(0.4),
                                style: StrokeStyle(lineWidth: 1.5, dash: [6])
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(isDisabled)
        }
    }
}

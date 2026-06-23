//
//  ConfigCard.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import SwiftUI

struct ConfigCard: View {
    @ObservedObject var config: Configuration
    let isActive: Bool
    let action: () -> Void
    let onUpdate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    openWindow(id: WindowID.configEditor.rawValue, value: config.id)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Edit")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isActive ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if config.sourceURL != nil {
                Button(action: onUpdate) {
                    Label("Update", systemImage: "arrow.clockwise")
                }
            }
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var metadata: String {
        let size = ByteCountFormatter.string(
            fromByteCount: Int64(config.content.utf8.count),
            countStyle: .file
        )
        return "\(size) · \(config.sourceURL ?? String(localized: "Local"))"
    }
}

//
//  LogsView.swift
//  Everywhere
//
//  Created by NodePassProject on 11/16/26.
//

import AppKit
import SwiftUI

struct LogsView: View {
    @ObservedObject var model: LogsModel

    @State private var searchText = ""

    private var visible: [LogEntry] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.entries }
        return model.entries.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        let entries = visible
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    LogRow(entry: entry)
                        .contextMenu {
                            Button {
                                copy(entry.text)
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .overlay {
            if entries.isEmpty {
                DashboardPlaceholder(
                    systemImage: "doc.text",
                    title: searchText.isEmpty ? "Waiting for logs" : "No matching logs"
                )
            }
        }
        .navigationTitle("Logs")
        .searchable(text: $searchText)
        .toolbar {
            DashboardToolbarSpacer()
            ToolbarItemGroup {
                Button {
                    model.isPaused.toggle()
                } label: {
                    Label(model.isPaused ? "Resume" : "Pause", systemImage: model.isPaused ? "play.fill" : "pause.fill")
                }
                .help(model.isPaused ? "Resume" : "Pause")

                Menu {
                    Picker("Log Level", selection: Binding(get: { model.level }, set: { level in Task { model.setLevel(level) } })) {
                        ForEach(LogLevel.allCases) { level in
                            Text(verbatim: level.title).tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                    Divider()
                    Button {
                        copy(entries.reversed()
                            .map { "\(DashboardFormat.clock.string(from: $0.time)) [\($0.level.rawValue)] \($0.text)" }
                            .joined(separator: "\n"))
                    } label: {
                        Label("Copy All", systemImage: "doc.on.doc")
                    }
                    .disabled(entries.isEmpty)
                    Button(role: .destructive) {
                        model.clear()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .disabled(model.entries.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
                .menuIndicator(.hidden)
            }
        }
        .onAppear { model.activate() }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: DashboardFormat.clock.string(from: entry.time))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(verbatim: entry.level.title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(DashboardColor.level(entry.level))
                .frame(width: 60, alignment: .leading)
            Text(verbatim: entry.text)
                .font(.callout.monospaced())
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(entry.id.isMultiple(of: 2) ? AnyShapeStyle(.quaternary.opacity(0.4)) : AnyShapeStyle(.clear))
        )
        .accessibilityElement(children: .combine)
    }
}

//
//  ContentView+Pager.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import NetworkExtension
import SwiftUI

extension ContentView {
    var corePager: some View {
        ZStack {
            corePage(for: store.selectedCore)
                .id(store.selectedCore)
                .transition(.opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.snappy, value: store.selectedCore)
        .safeAreaInset(edge: .bottom) { coreIndicator }
    }

    var coreIndicator: some View {
        HStack(spacing: 4) {
            ForEach(CoreType.allCases) { core in
                indicatorChip(for: core)
            }
        }
        .padding(4)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().strokeBorder(.separator.opacity(0.5)))
        .padding(.bottom, 12)
    }

    func indicatorChip(for core: CoreType) -> some View {
        let isSelected = store.selectedCore == core
        return Button {
            store.selectedCore = core
        } label: {
            HStack(spacing: 6) {
                Image(core.rawValue)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                if isSelected {
                    Text(core.displayName)
                        .font(.callout)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, isSelected ? 12 : 8)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.25) : .clear)
            )
            .animation(.snappy, value: isSelected)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(tunnel.status.isActive && !isSelected)
        .help(core.displayName)
    }

    func corePage(for core: CoreType) -> some View {
        HStack(spacing: 0) {
            brandingColumn(for: core)
                .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
            configurationColumn(for: core)
                .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 0)
        }
    }

    func brandingColumn(for core: CoreType) -> some View {
        VStack(spacing: 16) {
            Image(core.rawValue)
                .resizable()
                .interpolation(.high)
                .frame(width: 128, height: 128)
            Text(core.displayName)
                .font(.title)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    func configurationColumn(for core: CoreType) -> some View {
        let configs = store.getConfigurations(for: core)
        ScrollView(.vertical) {
            LazyVStack(spacing: 12) {
                if configs.isEmpty {
                    emptyPlaceholder
                } else {
                    ForEach(configs) { config in
                        ConfigCard(
                            config: config,
                            isActive: store.activeIDByCoreType[core] == config.id,
                            action: { activate(config) },
                            onRename: { promptRename(config) },
                            onDelete: { pendingDelete = config }
                        )
                    }
                }
                AddConfigurationCard(
                    isDownloading: isDownloading,
                    isDisabled: tunnel.coreRunning,
                    onNew: { promptCreate(for: core) },
                    onImport: {
                        importCore = core
                        fileImporting = true
                    },
                    onDownload: { promptDownload(for: core) }
                )
            }
            .padding()
        }
    }

    var emptyPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No Configurations")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

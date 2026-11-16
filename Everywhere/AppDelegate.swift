//
//  AppDelegate.swift
//  Everywhere
//
//  Created by NodePassProject on 5/26/26.
//

import AppKit
import Combine
import NetworkExtension

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var isHeadless = false
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        TunnelManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshStatusItem() }
            .store(in: &cancellables)
        refreshStatusItem()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        guard TunnelManager.shared.status.isActive else { return true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            let hasWindow = NSApp.windows.contains {
                $0.isVisible && $0.styleMask.contains(.titled)
            }
            if !hasWindow { self.setHeadless(true) }
        }
        return false
    }

    // MARK: - Activation policy

    private func setHeadless(_ headless: Bool) {
        guard headless != isHeadless else { return }
        isHeadless = headless
        NSApp.setActivationPolicy(headless ? .accessory : .regular)
        refreshStatusItem()
    }

    // MARK: - Status item

    private var shouldShowStatusItem: Bool {
        TunnelManager.shared.status.isActive || isHeadless
    }

    private func refreshStatusItem() {
        guard shouldShowStatusItem else {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
                statusItem = nil
            }
            return
        }
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            configure(item.button)
            statusItem = item
        }
        statusItem?.menu = buildMenu()
    }

    private func configure(_ button: NSStatusBarButton?) {
        guard let button else { return }
        button.toolTip = "Everywhere"
        let base = NSImage(named: "everywhere")
            ?? NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "Everywhere")
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let image = base?.withSymbolConfiguration(config) ?? base
        image?.isTemplate = true
        button.image = image
    }

    private func buildMenu() -> NSMenu {
        let tunnel = TunnelManager.shared
        let menu = NSMenu()

        menu.addItem(disabledItem(statusTitle))
        if tunnel.status.isActive, let name = ConfigurationStore.shared.active?.name {
            menu.addItem(disabledItem(name))
        }

        menu.addItem(.separator())

        let open = NSMenuItem(
            title: String(localized: "Open Everywhere"),
            action: #selector(openApp),
            keyEquivalent: ""
        )
        open.target = self
        menu.addItem(open)

        if tunnel.status.isActive {
            let disconnect = NSMenuItem(
                title: String(localized: "Disconnect"),
                action: #selector(disconnectTunnel),
                keyEquivalent: ""
            )
            disconnect.target = self
            disconnect.isEnabled = !tunnel.status.isTransitioning
            menu.addItem(disconnect)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: String(localized: "Quit Everywhere"),
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private var statusTitle: String {
        switch TunnelManager.shared.status {
        case .connected: return String(localized: "Connected")
        case .connecting: return String(localized: "Connecting")
        case .disconnecting: return String(localized: "Disconnecting")
        case .reasserting: return String(localized: "Reconnecting")
        case .invalid: return String(localized: "Not Configured")
        default: return String(localized: "Disconnected")
        }
    }

    // MARK: - Actions

    @objc private func openApp() {
        setHeadless(false)
        bringWindowToFront()
    }

    private func bringWindowToFront() {
        if let window = NSApp.windows.first(where: { $0.styleMask.contains(.titled) }) {
            NSApp.activate(ignoringOtherApps: true)
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func disconnectTunnel() {
        guard let active = ConfigurationStore.shared.active else { return }
        Task { await TunnelManager.shared.setEnabled(false, configuration: active) }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

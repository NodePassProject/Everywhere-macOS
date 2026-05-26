//
//  NameInputAlert.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import AppKit

// macOS equivalent of the iOS UIAlertController-with-textfield pattern.
// Uses NSAlert with an accessory NSTextField so callers can keep the
// same imperative present/submit API as the iOS sibling.
enum NameInputAlert {
    static func present(
        title: String,
        message: String? = nil,
        placeholder: String = "Name",
        initialValue: String = "",
        onSubmit: @escaping (String) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        if let message { alert.informativeText = message }
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Save"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = placeholder
        field.stringValue = initialValue
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        alert.accessoryView = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            // Fall back to modal presentation if there is no host
            // window — runs at app launch before the window appears.
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { onSubmit(trimmed) }
            }
            return
        }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let trimmed = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            onSubmit(trimmed)
        }
        // Focus the field once the sheet is on screen.
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(field)
        }
    }
}

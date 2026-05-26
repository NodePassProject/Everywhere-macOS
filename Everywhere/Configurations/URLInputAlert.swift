//
//  URLInputAlert.swift
//  Everywhere
//
//  Created by NodePassProject on 5/2/26.
//

import AppKit

// Mirrors NameInputAlert: NSAlert with a text field that only fires
// onSubmit when the input is a valid http(s) URL.
enum URLInputAlert {
    static func present(
        title: String,
        message: String? = nil,
        placeholder: String = "https://",
        onSubmit: @escaping (URL) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        if let message { alert.informativeText = message }
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "Download"))
        alert.addButton(withTitle: String(localized: "Cancel"))

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = placeholder
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        alert.accessoryView = field

        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn,
               let url = parsed(field.stringValue) {
                onSubmit(url)
            }
            return
        }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn,
                  let url = parsed(field.stringValue) else { return }
            onSubmit(url)
        }
        DispatchQueue.main.async {
            alert.window.makeFirstResponder(field)
        }
    }

    private static func parsed(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url
    }
}

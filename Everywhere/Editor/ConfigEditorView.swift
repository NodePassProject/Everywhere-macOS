//
//  ConfigEditorView.swift
//  Everywhere
//
//  Created by Argsment Limited on 5/2/26.
//

import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import SwiftUI

struct ConfigEditorView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let language: String

    @State private var editorState = SourceEditorState(
        cursorPositions: [CursorPosition(line: 1, column: 1)]
    )

    var body: some View {
        SourceEditor(
            $text,
            language: codeLanguage,
            configuration: SourceEditorConfiguration(
                appearance: .init(
                    theme: colorScheme == .dark ? .dark : .light,
                    font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                    lineHeightMultiple: 1.2,
                    wrapLines: false,
                    tabWidth: 2
                ),
                behavior: .init(indentOption: .spaces(count: 2)),
                peripherals: .init(showGutter: true, showMinimap: false)
            ),
            state: $editorState
        )
    }

    private var codeLanguage: CodeLanguage {
        switch language {
        case "json": return .json
        case "yaml": return .yaml
        default: return .default
        }
    }
}

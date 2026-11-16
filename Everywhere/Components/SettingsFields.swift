//
//  SettingsFields.swift
//  Everywhere
//
//  Created by NodePassProject on 11/16/26.
//

import SwiftUI

// MARK: - Text field

struct SettingTextField: View {
    let title: LocalizedStringKey
    let placeholder: String
    @Binding var value: String
    var validate: (String) -> Bool = { _ in true }

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(title, text: $draft, prompt: Text(verbatim: placeholder))
            .autocorrectionDisabled()
            .foregroundColor(isValid ? nil : .red)
            .focused($isFocused)
            .onSubmit(commit)
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in draft = newValue }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onDisappear(perform: commit)
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        validate(trimmed)
    }

    private func commit() {
        if isValid, trimmed != value {
            value = trimmed
        }
        draft = value
    }
}

struct SettingNumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        SettingTextField(
            title: title,
            placeholder: String(value),
            value: Binding(
                get: { String(value) },
                set: { if let number = Int($0) { value = number } }
            ),
            validate: { Int($0).map(range.contains) ?? false }
        )
    }
}

// MARK: - List

struct EditableListSection: View {
    let title: LocalizedStringKey
    let placeholder: String
    @Binding var items: [String]
    var minimumCount = 0
    var validate: (String) -> Bool = { !$0.isEmpty }

    @State private var draft = ""

    var body: some View {
        Section(title) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                HStack {
                    Text(verbatim: item)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        items.removeAll { $0 == item }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(canDelete ? Color.red : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canDelete)
                    .accessibilityLabel("Delete")
                }
                .contextMenu {
                    Button {
                        items.swapAt(index, index - 1)
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                    .disabled(index == 0)
                    Button {
                        items.swapAt(index, index + 1)
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                    .disabled(index == items.count - 1)
                }
            }

            HStack {
                TextField("Add", text: $draft, prompt: Text(verbatim: placeholder))
                    .labelsHidden()
                    .multilineTextAlignment(.leading)
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .onSubmit(add)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(canAdd ? Color.green : Color.secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!canAdd)
                .accessibilityLabel("Add")
            }
        }
    }

    private var trimmed: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAdd: Bool {
        validate(trimmed) && !items.contains(trimmed)
    }

    private var canDelete: Bool {
        items.count > minimumCount
    }

    private func add() {
        guard canAdd else { return }
        items.append(trimmed)
        draft = ""
    }
}

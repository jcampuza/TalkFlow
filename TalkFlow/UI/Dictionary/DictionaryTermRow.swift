import SwiftUI

struct DictionaryTermRow: View {
    let term: DictionaryTerm
    let onToggle: () -> Void
    let onEdit: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editText: String = ""
    @State private var isHovering = false
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Enable/Disable toggle
            Toggle("", isOn: Binding(
                get: { term.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.small)

            // Term text (editable)
            if isEditing {
                TextField("Term", text: $editText, onCommit: commitEdit)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .onExitCommand {
                        cancelEdit()
                    }
            } else {
                Text(term.term)
                    .foregroundColor(term.isEnabled ? .primary : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditing()
                    }
            }

            Spacer()

            // Delete button (visible on hover)
            if isHovering && !isEditing {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete term")
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isHovering ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func startEditing() {
        editText = term.term
        isEditing = true
        isTextFieldFocused = true
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != term.term {
            onEdit(trimmed)
        }
        isEditing = false
    }

    private func cancelEdit() {
        isEditing = false
        editText = term.term
    }
}

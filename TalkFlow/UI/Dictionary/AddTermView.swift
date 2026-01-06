import SwiftUI

struct AddTermView: View {
    let isAtLimit: Bool
    let onAdd: (String) -> Void

    @State private var newTerm: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add new term...", text: $newTerm)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .disabled(isAtLimit)
                .onSubmit {
                    addTerm()
                }

            Button(action: addTerm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .foregroundColor(canAdd ? .accentColor : .secondary)
            .disabled(!canAdd)
            .help(isAtLimit ? "Dictionary limit reached (50 terms)" : "Add term")
        }
        .padding()
    }

    private var canAdd: Bool {
        !isAtLimit && !newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onAdd(trimmed)
        newTerm = ""
        isTextFieldFocused = true
    }
}

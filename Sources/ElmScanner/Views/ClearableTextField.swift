import SwiftUI

/// A text field with the system's clear button (the gray ⓧ) while it is being edited.
///
/// On iPhone the system draws that button itself (turned on for every text field in
/// `ElmScannerPhoneApp`), so this is a plain `TextField`. The Mac has it only for search
/// fields, so here the same symbol is drawn beside the field while it has focus and text.
struct ClearableTextField: View {
    private let title: LocalizedStringResource
    @Binding private var text: String
    #if os(macOS)
    @FocusState private var focused: Bool
    #endif

    init(_ title: LocalizedStringResource, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 4) {
            TextField(String(localized: title), text: $text)
                .focused($focused)
            if focused && !text.isEmpty {
                Button {
                    text = ""
                    focused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        #else
        TextField(String(localized: title), text: $text)
        #endif
    }
}

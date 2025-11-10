// ABOUTME: Search bar component with text field, search icon, and clear button
// ABOUTME: Provides query binding and keyboard dismiss on scroll

import SwiftUI

struct SearchBar: View {
    @Binding var query: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
                .accessibilityHidden(true)

            // Text field
            TextField("Search notes...", text: $query)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .disableAutocorrection(true)
                .accessibilityLabel("Search notes")
                .accessibilityHint("Enter text to search for notes")

            // Clear button
            if !query.isEmpty {
                Button(action: {
                    query = ""
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the search query")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Previews

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            SearchBar(query: .constant(""))
                .previewDisplayName("Empty")
                .previewLayout(.sizeThatFits)
                .padding()

            // With text
            SearchBar(query: .constant("test query"))
                .previewDisplayName("With Query")
                .previewLayout(.sizeThatFits)
                .padding()

            // In dark mode
            SearchBar(query: .constant("dark mode"))
                .previewDisplayName("Dark Mode")
                .previewLayout(.sizeThatFits)
                .padding()
                .preferredColorScheme(.dark)
        }
    }
}

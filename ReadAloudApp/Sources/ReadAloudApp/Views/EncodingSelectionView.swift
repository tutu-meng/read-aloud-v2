import SwiftUI

/// View for selecting text encoding when first loading a book
struct EncodingSelectionView: View {
    let bookTitle: String
    let onEncodingSelected: (String) -> Void
    let onCancel: () -> Void
    
    @State private var selectedEncoding = "UTF-8"
    
    private let availableEncodings = [
        ("UTF-8", "UTF-8 (Most common for modern files)"),
        ("GBK", "GBK (Chinese Simplified)"),
        ("UTF-16", "UTF-16 (Windows Unicode)"),
        ("Windows-1252", "Windows-1252 (Western European)"),
        ("ISO-8859-1", "ISO-8859-1 (Latin-1)")
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Text Encoding")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose the text encoding for:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(bookTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // Encoding options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Encodings:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(availableEncodings, id: \.0) { encoding, description in
                        Button(action: {
                            selectedEncoding = encoding
                        }) {
                            HStack {
                                Image(systemName: selectedEncoding == encoding ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedEncoding == encoding ? .blue : .gray)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(encoding)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(selectedEncoding == encoding ? Color.blue.opacity(0.1) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                // Help text
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Tip:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("• Choose UTF-8 for most modern files\n• Choose GBK for Chinese text files\n• If text appears garbled, try a different encoding")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
                
                // Action buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Load Book") {
                        onEncodingSelected(selectedEncoding)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Text Encoding")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    EncodingSelectionView(
        bookTitle: "Sample Book.txt",
        onEncodingSelected: { encoding in
            print("Selected encoding: \(encoding)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
} 
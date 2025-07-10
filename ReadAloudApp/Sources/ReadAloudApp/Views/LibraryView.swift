//
//  LibraryView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

/// LibraryView displays the collection of imported books
struct LibraryView: View {
    @ObservedObject var viewModel: LibraryViewModel
    @State private var showingFilePicker = false
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.books.isEmpty {
                    emptyStateView
                } else {
                    bookListView
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Import") {
                        showingFilePicker = true
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker(
                    onFileSelected: { fileURL in
                        showingFilePicker = false
                        viewModel.handleFileImport(fileURL)
                    },
                    onDismiss: {
                        showingFilePicker = false
                    }
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Books Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the Import button to add your first book")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Import Book") {
                showingFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var bookListView: some View {
        List(viewModel.books) { book in
            BookRow(book: book) {
                viewModel.selectBook(book)
            }
        }
    }
}

/// BookRow represents a single book in the library list
struct BookRow: View {
    let book: Book
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(formatFileSize(book.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 
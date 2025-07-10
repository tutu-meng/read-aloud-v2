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
    @State private var bookToDelete: Book?
    @State private var showingDeleteConfirmation = false
    @State private var shouldDeleteFile = false
    
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
            .sheet(isPresented: $viewModel.showingEncodingSelection) {
                if let pendingBook = viewModel.bookPendingEncoding {
                    EncodingSelectionView(
                        bookTitle: pendingBook.title,
                        onEncodingSelected: { encoding in
                            viewModel.handleEncodingSelection(encoding)
                        },
                        onCancel: {
                            viewModel.cancelEncodingSelection()
                        }
                    )
                }
            }
            .alert("Delete Book", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    bookToDelete = nil
                    shouldDeleteFile = false
                }
                Button(shouldDeleteFile ? "Delete File" : "Remove", role: .destructive) {
                    if let book = bookToDelete {
                        viewModel.removeBook(book, deleteFile: shouldDeleteFile)
                    }
                    bookToDelete = nil
                    shouldDeleteFile = false
                }
            } message: {
                if let book = bookToDelete {
                    Text(shouldDeleteFile ? 
                         "Are you sure you want to permanently delete \"\(book.title)\" and its file?" :
                         "Are you sure you want to remove \"\(book.title)\" from your library?")
                }
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
        List {
            ForEach(viewModel.books) { book in
                BookRow(book: book, onTap: {
                    viewModel.selectBook(book)
                }, onDelete: { deleteFile in
                    bookToDelete = book
                    shouldDeleteFile = deleteFile
                    showingDeleteConfirmation = true
                })
            }
            .onDelete(perform: deleteBooks)
        }
    }
    
    /// Handle book deletion from swipe gesture
    /// - Parameter indexSet: The indices of books to delete
    private func deleteBooks(at indexSet: IndexSet) {
        for index in indexSet {
            let book = viewModel.books[index]
            bookToDelete = book
            shouldDeleteFile = false // Swipe to delete only removes from library
            showingDeleteConfirmation = true
            break // Only handle one book at a time for confirmation
        }
    }
}

/// BookRow represents a single book in the library list
struct BookRow: View {
    let book: Book
    let onTap: () -> Void
    let onDelete: ((Bool) -> Void)?
    
    init(book: Book, onTap: @escaping () -> Void, onDelete: ((Bool) -> Void)? = nil) {
        self.book = book
        self.onTap = onTap
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(formatFileSize(book.fileSize))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(book.textEncoding)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let onDelete = onDelete {
                Button("Remove from Library", role: .destructive) {
                    onDelete(false)
                }
                
                Button("Delete File", role: .destructive) {
                    onDelete(true)
                }
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 
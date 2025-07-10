//
//  BookSettingsView.swift
//  ReadAloudApp
//
//  Created for FILE-7: Character encoding selection
//

import SwiftUI

/// BookSettingsView allows users to customize book-specific settings like encoding
struct BookSettingsView: View {
    @ObservedObject var readerViewModel: ReaderViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedEncoding: String
    @State private var showingEncodingAlert = false
    
    // MARK: - Initialization
    
    init(readerViewModel: ReaderViewModel) {
        self.readerViewModel = readerViewModel
        self._selectedEncoding = State(initialValue: readerViewModel.currentEncoding)
    }
    
    var body: some View {
        NavigationView {
            Form {
                bookInfoSection
                encodingSection
                globalSettingsSection
            }
            .navigationTitle("Book Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var bookInfoSection: some View {
        Section(header: Text("Book Information")) {
            VStack(alignment: .leading, spacing: 8) {
                Text(readerViewModel.book.title)
                    .font(.headline)
                
                Text("File Size: \(ByteCountFormatter.string(fromByteCount: readerViewModel.book.fileSize, countStyle: .file))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Imported: \(readerViewModel.book.importedDate, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
    
    private var encodingSection: some View {
        Section(header: Text("Text Encoding"), 
                footer: Text("If the text appears garbled, try changing the encoding. This setting is specific to this book.")) {
            
            Picker("Encoding", selection: $selectedEncoding) {
                ForEach(readerViewModel.availableEncodings, id: \.self) { encoding in
                    Text(encoding).tag(encoding)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedEncoding) { newEncoding in
                if newEncoding != readerViewModel.currentEncoding {
                    showingEncodingAlert = true
                }
            }
            
            HStack {
                Text("Current Encoding")
                Spacer()
                Text(readerViewModel.currentEncoding)
                    .foregroundColor(.secondary)
            }
        }
        .alert("Change Encoding?", isPresented: $showingEncodingAlert) {
            Button("Cancel", role: .cancel) {
                selectedEncoding = readerViewModel.currentEncoding
            }
            Button("Change") {
                readerViewModel.changeBookEncoding(to: selectedEncoding)
            }
        } message: {
            Text("Changing the encoding will reload the book and may take a moment. Your reading progress will be preserved.")
        }
    }
    
    private var globalSettingsSection: some View {
        Section(header: Text("Global Settings")) {
            NavigationLink(destination: SettingsView(viewModel: readerViewModel.makeSettingsViewModel(), isSheet: true)) {
                Label("Text & Appearance", systemImage: "textformat")
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

// MARK: - Preview

struct BookSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let coordinator = AppCoordinator()
        let book = Book(
            title: "Sample Book",
            fileURL: URL(fileURLWithPath: "/sample.txt"),
            contentHash: "sample123",
            fileSize: 1024,
            textEncoding: "UTF-8"
        )
        let readerViewModel = ReaderViewModel(book: book, coordinator: coordinator)
        
        BookSettingsView(readerViewModel: readerViewModel)
    }
} 
//
//  DocumentPicker.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// DocumentPicker is a UIViewControllerRepresentable that wraps UIDocumentPickerViewController
/// to allow SwiftUI views to present the iOS document picker for importing text files
struct DocumentPicker: UIViewControllerRepresentable {
    
    /// Callback closure that receives the selected file URL
    let onFileSelected: (URL) -> Void
    
    /// Callback closure that handles picker dismissal without selection
    let onDismiss: () -> Void
    
    // MARK: - UIViewControllerRepresentable
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create document picker configured for plain text files only
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.plainText])
        
        // Configure picker settings
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        
        // Set delegate
        picker.delegate = context.coordinator
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed for this implementation
    }
    
    // MARK: - Coordinator
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    /// Coordinator handles the UIDocumentPickerViewController delegate methods
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        // MARK: - UIDocumentPickerDelegate
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Handle successful file selection
            guard let selectedURL = urls.first else {
                debugPrint("📁 DocumentPicker: No file selected")
                parent.onDismiss()
                return
            }
            
            debugPrint("📁 DocumentPicker: File selected: \(selectedURL.lastPathComponent)")
            
            // Verify it's a text file
            guard selectedURL.pathExtension.lowercased() == "txt" else {
                debugPrint("⚠️ DocumentPicker: Selected file is not a .txt file")
                parent.onDismiss()
                return
            }
            
            // Call the success callback
            parent.onFileSelected(selectedURL)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            debugPrint("📁 DocumentPicker: User cancelled file selection")
            parent.onDismiss()
        }
    }
}

// MARK: - Preview
struct DocumentPicker_Previews: PreviewProvider {
    static var previews: some View {
        // DocumentPicker is presented modally, so we'll show a button to trigger it
        Button("Show Document Picker") {
            // Preview placeholder
        }
        .sheet(isPresented: .constant(true)) {
            DocumentPicker(
                onFileSelected: { url in
                    print("Selected file: \(url)")
                },
                onDismiss: {
                    print("Picker dismissed")
                }
            )
        }
    }
} 
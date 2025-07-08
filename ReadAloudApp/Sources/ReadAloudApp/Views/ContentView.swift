//
//  ContentView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    
    var body: some View {
        ZStack {
            // Main content based on current view
            switch appCoordinator.currentView {
            case .library:
                LibraryView(viewModel: appCoordinator.makeLibraryViewModel())
            case .reader:
                if let book = appCoordinator.selectedBook {
                    ReaderView(viewModel: appCoordinator.makeReaderViewModel(for: book))
                } else {
                    // Fallback if no book is selected
                    LibraryView(viewModel: appCoordinator.makeLibraryViewModel())
                }
            case .settings:
                SettingsView(viewModel: appCoordinator.makeSettingsViewModel())
            case .loading:
                LoadingView()
            }
            
            // Error overlay
            if let errorMessage = appCoordinator.errorMessage {
                VStack {
                    Spacer()
                    ErrorBanner(message: errorMessage) {
                        appCoordinator.clearError()
                    }
                    .padding()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: appCoordinator.errorMessage)
            }
        }
    }
}

/// Loading view shown during app initialization or heavy operations
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
    }
}

/// Error banner component for displaying error messages
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            
            Text(message)
                .foregroundColor(.white)
                .font(.subheadline)
                .lineLimit(2)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red)
                .shadow(radius: 5)
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppCoordinator())
} 
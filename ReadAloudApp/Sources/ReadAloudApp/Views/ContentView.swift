//
//  ContentView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

/// ContentView is the root view that manages navigation between different screens
struct ContentView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    
    var body: some View {
        switch coordinator.currentView {
        case .library:
            LibraryView(viewModel: coordinator.makeLibraryViewModel())
        case .reader:
            if let book = coordinator.selectedBook {
                ReaderView(viewModel: coordinator.makeReaderViewModel(for: book))
            } else {
                // Fallback to library if no book is selected
                LibraryView(viewModel: coordinator.makeLibraryViewModel())
            }
        case .settings:
            SettingsView(viewModel: coordinator.makeSettingsViewModel())
        }
    }
} 
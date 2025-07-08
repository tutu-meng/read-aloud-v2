//
//  ReaderView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

/// ReaderView displays the paginated content of a book
struct ReaderView: View {
    @ObservedObject var viewModel: ReaderViewModel
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if viewModel.isLoading {
                    loadingView
                } else {
                    readerContent(geometry: geometry)
                }
            }
            .navigationTitle(viewModel.book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Library") {
                        viewModel.goBackToLibrary()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { viewModel.toggleSpeech() }) {
                            Image(systemName: viewModel.isSpeaking ? "speaker.slash" : "speaker.2")
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "textformat")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                // TODO: Implement settings view
                Text("Settings Placeholder")
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading book...")
                .padding(.top)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func readerContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Page content using TabView for pagination
            TabView(selection: $viewModel.currentPage) {
                ForEach(0..<viewModel.totalPages, id: \.self) { pageIndex in
                    PageView(
                        content: generatePageContent(for: pageIndex),
                        pageIndex: pageIndex
                    )
                    .tag(pageIndex)
                    .frame(width: geometry.size.width, height: geometry.size.height - 100)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.default, value: viewModel.currentPage)
            
            // Page indicator
            pageIndicator
                .padding()
                .background(Color(UIColor.systemBackground))
        }
    }
    
    private var pageIndicator: some View {
        HStack {
            Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.totalPages > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<min(viewModel.totalPages, 10), id: \.self) { index in
                        Circle()
                            .fill(index == viewModel.currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .frame(height: 30)
    }
    
    /// Generate placeholder content for a specific page
    private func generatePageContent(for pageIndex: Int) -> String {
        // If we're on the current page, use the viewModel's content
        // Otherwise, generate placeholder content
        if pageIndex == viewModel.currentPage {
            return viewModel.pageContent
        } else {
            return """
            Page \(pageIndex + 1) of \(viewModel.book.title)
            
            This is placeholder content for page \(pageIndex + 1).
            
            In a real implementation, this would contain the actual paginated text from the book file. The content would be calculated by the PaginationService based on the current font settings and view dimensions.
            
            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
            
            Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
            """
        }
    }
}

/// PageView displays a single page of content
struct PageView: View {
    let content: String
    let pageIndex: Int
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
} 
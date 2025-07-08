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
        // Always use the viewModel's content when on current page
        // This ensures we get the actual book content when available
        if pageIndex == viewModel.currentPage {
            return viewModel.pageContent
        } else {
            // For other pages, return placeholder to avoid loading all pages at once
            return "Loading page \(pageIndex + 1)..."
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
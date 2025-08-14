//
//  ReaderView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

/// ReaderView displays the paginated content of a book
struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    
    init(viewModel: ReaderViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
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
                        viewModel.closeBook()
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
                SettingsView(viewModel: SettingsViewModel(coordinator: viewModel.coordinator), isSheet: true)
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
                    .frame(width: geometry.size.width, height: geometry.size.height-100)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.default, value: viewModel.currentPage)
            .onAppear {
                // Provide exact text drawable size to viewModel for pagination calculations
                let textSize = LayoutMetrics.computeTextDrawableSize(container: geometry.size)
                viewModel.updateViewSize(textSize)
            }
            .onChange(of: geometry.size) { _, newSize in
                // Update view size when geometry changes
                let textSize = LayoutMetrics.computeTextDrawableSize(container: newSize)
                viewModel.updateViewSize(textSize)
            }
            
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
            
            // Removed percentage indicator per UI-5 follow-up; keep left page text only
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
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
            .actionSheet(isPresented: Binding<Bool>(
                get: { viewModel.shouldPresentTTSPicker },
                set: { _ in }
            )) {
                ActionSheet(
                    title: Text("Choose TTS language"),
                    message: Text("This will be used for reading aloud."),
                    buttons: [
                        .default(Text("English (United States)")) { viewModel.confirmTTSLanguageSelection(code: "en-US") },
                        .default(Text("Chinese (Simplified)")) { viewModel.confirmTTSLanguageSelection(code: "zh-CN") },
                        .cancel { viewModel.shouldPresentTTSPicker = false }
                    ]
                )
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
        let pageHeight = geometry.size.height - LayoutMetrics.chromeBottomHeight
        return VStack(spacing: 0) {
            // Efficient page view using UIPageViewController (only 3 views at a time)
            BookPagerView(
                viewModel: viewModel,
                pageSize: CGSize(width: geometry.size.width, height: pageHeight)
            )
            .frame(width: geometry.size.width, height: pageHeight)
            .onAppear {
                let textSize = LayoutMetrics.computeTextDrawableSize(container: geometry.size)
                viewModel.updateViewSize(textSize)
            }
            .onChange(of: geometry.size) { _, newSize in
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
            if viewModel.isSeedMode {
                Text("~\(viewModel.seedReadingPercentage)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(height: 8)
    }
    
}
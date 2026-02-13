//
//  SettingsView.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

/// SettingsView allows users to customize reading preferences
struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.presentationMode) var presentationMode
    
    /// Whether this view is presented as a sheet (vs full screen navigation)
    let isSheet: Bool
    
    // MARK: - Initialization
    
    init(viewModel: SettingsViewModel, isSheet: Bool = false) {
        self.viewModel = viewModel
        self.isSheet = isSheet
    }
    
    var body: some View {
        NavigationView {
            Form {
                textSettingsSection
                appearanceSection
                speechSettingsSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if isSheet {
                            // For sheet presentation, just save settings and dismiss
                            viewModel.saveSettingsOnly()
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            // For full navigation, close normally
                            viewModel.close()
                        }
                    }
                }
            }
        }
    }
    
    private var textSettingsSection: some View {
        Section(header: Text("Text Settings")) {
            // Font Size
            VStack(alignment: .leading) {
                Text("Font Size: \(Int(viewModel.userSettings.fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.userSettings.fontSize, 
                      in: UserSettings.fontSizeRange, 
                      step: 1)
            }
            
            // Font Selection
            Picker("Font", selection: $viewModel.userSettings.fontName) {
                ForEach(UserSettings.availableFonts, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            
            // Line Spacing
            VStack(alignment: .leading) {
                Text("Line Spacing: \(viewModel.userSettings.lineSpacing, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.userSettings.lineSpacing, 
                      in: UserSettings.lineSpacingRange, 
                      step: 0.1)
            }
        }
    }
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme", selection: Binding(
                get: { SettingsViewModel.ColorTheme(from: viewModel.userSettings.theme) },
                set: { viewModel.userSettings.theme = $0.themeString }
            )) {
                ForEach(SettingsViewModel.ColorTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var speechSettingsSection: some View {
        Section(header: Text("Text-to-Speech")) {
            Picker("Language", selection: Binding(
                get: { viewModel.userSettings.speechLanguageCode ?? "en-US" },
                set: { viewModel.userSettings.speechLanguageCode = $0 }
            )) {
                Text("English (US)").tag("en-US")
                Text("中文 (简体)").tag("zh-CN")
            }

            VStack(alignment: .leading) {
                Text("Speech Rate: \(viewModel.userSettings.speechRate, specifier: "%.1f")x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: Binding(
                    get: { Double(viewModel.userSettings.speechRate) },
                    set: { viewModel.userSettings.speechRate = Float($0) }
                ), in: Double(UserSettings.speechRateRange.lowerBound)...Double(UserSettings.speechRateRange.upperBound),
                   step: 0.1)
            }
        }
    }
} 
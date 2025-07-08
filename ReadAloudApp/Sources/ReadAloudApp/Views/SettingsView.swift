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
                        viewModel.close()
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private var textSettingsSection: some View {
        Section(header: Text("Text Settings")) {
            // Font Size
            VStack(alignment: .leading) {
                Text("Font Size: \(Int(viewModel.fontSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.fontSize, in: 12...32, step: 1)
            }
            
            // Font Selection
            Picker("Font", selection: $viewModel.fontName) {
                Text("System").tag("System")
                Text("Georgia").tag("Georgia")
                Text("Helvetica").tag("Helvetica")
                Text("Times New Roman").tag("Times New Roman")
                Text("Courier").tag("Courier")
            }
            
            // Line Spacing
            VStack(alignment: .leading) {
                Text("Line Spacing: \(viewModel.lineSpacing, specifier: "%.1f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.lineSpacing, in: 0.8...2.0, step: 0.1)
            }
        }
    }
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            Picker("Theme", selection: $viewModel.theme) {
                ForEach(SettingsViewModel.ColorTheme.allCases, id: \.self) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var speechSettingsSection: some View {
        Section(header: Text("Text-to-Speech")) {
            VStack(alignment: .leading) {
                Text("Speech Rate: \(viewModel.speechRate, specifier: "%.1f")x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $viewModel.speechRate, in: 0.5...2.0, step: 0.1)
            }
        }
    }
} 
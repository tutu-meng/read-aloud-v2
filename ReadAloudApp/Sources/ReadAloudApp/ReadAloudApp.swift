//
//  ReadAloudApp.swift
//  ReadAloudApp
//
//  Created on 2024
//

import SwiftUI

@main
struct ReadAloudApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
        }
    }
} 
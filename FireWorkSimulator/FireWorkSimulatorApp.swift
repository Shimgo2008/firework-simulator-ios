//
//  FireWorkSimulatorApp.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/07/06.
//

import SwiftUI

@main
struct FireWorkSimulatorApp: App {
    @StateObject private var p2pManager = P2PManager()

    var body: some Scene {
        WindowGroup {
            ARViewScreen()
                .onAppear {
                    print("FireWorkSimulator App started successfully")
                }
                .environmentObject(p2pManager) // P2PManagerを環境オブジェクトとして提供
        }
    }
}

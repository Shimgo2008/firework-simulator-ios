//
//  FireWorkSimulatorApp.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/07/06.
//

import SwiftUI

@main
struct FireWorkSimulatorApp: App {
    var body: some Scene {
        WindowGroup {
            ARViewScreen()
                .onAppear {
                    print("FireWorkSimulator App started successfully")
                }
        }
    }
}

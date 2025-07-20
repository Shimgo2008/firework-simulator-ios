//
//  FireWorkSimulatorApp.swift
//  FireWorkSimulator
//
//  Created by 岩澤慎平 on 2025/07/06.
//

import SwiftUI

@main
struct FireWorkSimulatorApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .onAppear {
                    print("FireWorkSimulator App started successfully")
                }
        }
    }
}

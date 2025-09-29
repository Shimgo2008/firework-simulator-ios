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
    @StateObject private var weatherService = WeatherService()
    @StateObject private var sensoryEffectsManager = SensoryEffectsManager()

    var body: some Scene {
        WindowGroup {
            ARViewScreen()
                .onAppear {
                    print("FireWorkSimulator App started successfully ✨")
                    
                    // Start weather tracking for temperature-based sound physics
                    weatherService.startTemperatureTracking()
                }
                .environmentObject(p2pManager) // P2PManagerを環境オブジェクトとして提供
                .environmentObject(weatherService)
                .environmentObject(sensoryEffectsManager)
                .onReceive(weatherService.$soundSpeed) { newSoundSpeed in
                    // Update sound speed in sensory effects manager
                    sensoryEffectsManager.updateSoundSpeed(newSoundSpeed)
                }
        }
    }
}

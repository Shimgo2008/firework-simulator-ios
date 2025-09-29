//
//  ShellListViewModel.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/08/16.
//

import SwiftUI

@MainActor
class ShellListViewModel: ObservableObject {
    @Published var shells: [FireworkShell2D] = []
    @Published var searchText: String = ""
    
    private let userDefaultsKey = "SavedFireworkShells"

    var filteredShells: [FireworkShell2D] {
        if searchText.isEmpty {
            return shells
        } else {
            return shells.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    init() {
        loadData()
        
        // Add some Gen Z default shells if none exist ✨
        if shells.isEmpty {
            createDefaultGenZShells()
        }
    }

    // MARK: - Data Manipulation Methods
    func addShell(_ shell: FireworkShell2D) {
        shells.append(shell)
        saveData()
    }

    func removeShell(_ shell: FireworkShell2D) {
        shells.removeAll { $0.id == shell.id }
        saveData()
    }

    // MARK: - Persistence Methods
    private func saveData() {
        do {
            let data = try JSONEncoder().encode(shells)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Error saving shells: \(error.localizedDescription)")
        }
    }
    
    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }
        do {
            shells = try JSONDecoder().decode([FireworkShell2D].self, from: data)
        } catch {
            print("Error loading shells: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Gen Z Default Shells 🌟
    private func createDefaultGenZShells() {
        // Neon Dreams 💜
        let neonDream = FireworkShell2D(
            name: "Neon Dreams ✨",
            stars: [
                Star2D(position: CGPoint(x: 0, y: -80), color: .purple, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: 60, y: -40), color: .pink, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 80, y: 0), color: .cyan, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: 60, y: 40), color: .mint, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 0, y: 80), color: .purple, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: -60, y: 40), color: .pink, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: -80, y: 0), color: .cyan, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: -60, y: -40), color: .mint, shape: .circle, size: 10),
            ],
            shellRadius: 120
        )
        
        // Sunset Vibes 🌅
        let sunsetVibes = FireworkShell2D(
            name: "Sunset Vibes 🌅",
            stars: [
                Star2D(position: CGPoint(x: 0, y: -100), color: .orange, shape: .circle, size: 15),
                Star2D(position: CGPoint(x: 70, y: -70), color: .red, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: 100, y: 0), color: .yellow, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 70, y: 70), color: .orange, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: 0, y: 100), color: .red, shape: .circle, size: 15),
                Star2D(position: CGPoint(x: -70, y: 70), color: .yellow, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: -100, y: 0), color: .orange, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: -70, y: -70), color: .red, shape: .circle, size: 12),
            ],
            shellRadius: 140
        )
        
        // Ocean Waves 🌊
        let oceanWaves = FireworkShell2D(
            name: "Ocean Waves 🌊",
            stars: [
                Star2D(position: CGPoint(x: -90, y: -30), color: .blue, shape: .circle, size: 14),
                Star2D(position: CGPoint(x: -45, y: -60), color: .cyan, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 0, y: -90), color: .teal, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: 45, y: -60), color: .blue, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 90, y: -30), color: .cyan, shape: .circle, size: 14),
                Star2D(position: CGPoint(x: 90, y: 30), color: .teal, shape: .circle, size: 14),
                Star2D(position: CGPoint(x: 45, y: 60), color: .blue, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: 0, y: 90), color: .cyan, shape: .circle, size: 12),
                Star2D(position: CGPoint(x: -45, y: 60), color: .teal, shape: .circle, size: 10),
                Star2D(position: CGPoint(x: -90, y: 30), color: .blue, shape: .circle, size: 14),
            ],
            shellRadius: 130
        )
        
        // Kawaii Sparkle 🎀
        let kawaiiSparkle = FireworkShell2D(
            name: "Kawaii Sparkle 🎀",
            stars: [
                Star2D(position: CGPoint(x: 0, y: 0), color: .pink, shape: .circle, size: 20),
                Star2D(position: CGPoint(x: 30, y: -30), color: .white, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: 42, y: 0), color: .pink, shape: .circle, size: 6),
                Star2D(position: CGPoint(x: 30, y: 30), color: .white, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: 0, y: 42), color: .pink, shape: .circle, size: 6),
                Star2D(position: CGPoint(x: -30, y: 30), color: .white, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: -42, y: 0), color: .pink, shape: .circle, size: 6),
                Star2D(position: CGPoint(x: -30, y: -30), color: .white, shape: .circle, size: 8),
                Star2D(position: CGPoint(x: 0, y: -42), color: .pink, shape: .circle, size: 6),
            ],
            shellRadius: 60
        )
        
        shells = [neonDream, sunsetVibes, oceanWaves, kawaiiSparkle]
        saveData()
    }
}

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
}

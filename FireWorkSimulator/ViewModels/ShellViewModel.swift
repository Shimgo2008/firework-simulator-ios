import Foundation
import SwiftUI

class ShellViewModel: ObservableObject {
    @Published var shells: [FireworkShell2D] = []
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let shellsFileName = "firework_shells.json"
    
    init() {
        loadShellsFromJSON()
    }
    
    // FireworkShell2DをJSON保存
    func saveShellsToJSON() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(shells)
            let fileURL = documentsPath.appendingPathComponent(shellsFileName)
            try data.write(to: fileURL)
            print("花火玉データを保存しました: \(fileURL.path)")
        } catch {
            print("保存エラー: \(error)")
        }
    }
    
    // FireworkShell2DをJSONから読み込み
    func loadShellsFromJSON() {
        let fileURL = documentsPath.appendingPathComponent(shellsFileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("保存ファイルが存在しません")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            shells = try decoder.decode([FireworkShell2D].self, from: data)
            print("花火玉データを読み込みました: \(shells.count)個")
        } catch {
            print("読み込みエラー: \(error)")
        }
    }
    
    // 新しい花火玉を追加
    func addShell(_ shell: FireworkShell2D) {
        shells.append(shell)
        saveShellsToJSON()
    }
    
    // 花火玉を削除
    func removeShell(at index: Int) {
        guard index < shells.count else { return }
        shells.remove(at: index)
        saveShellsToJSON()
    }
} 
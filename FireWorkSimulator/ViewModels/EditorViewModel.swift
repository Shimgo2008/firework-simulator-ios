//
//  EditorViewModel.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/08/16.
//

import SwiftUI

class EditorViewModel: ObservableObject {
    // MARK: - Published Properties (UIの状態)
    @Published var stars: [Star2D] = []
    @Published var selectedStarID: UUID?

    @Published var selectedTool: StarTool = .single
    @Published var selectedColor: Color = .red
    @Published var selectedStarSize: CGFloat = 12.0
    
    // パターンツール用の設定
    @Published var spacing: CGFloat = 20.0
    @Published var previewRadius: CGFloat = 80.0
    @Published var previewStars: [Star2D] = []

    // アラート表示用の状態
    @Published var showSaveAlert: Bool = false
    @Published var showClearAlert: Bool = false
    @Published var fireworkName: String = ""

    // MARK: - Enums
    enum StarTool: String, CaseIterable, Identifiable {
        case  circle, single, eraser, spiral, grid
        var id: String { self.rawValue }
    }

    // MARK: - Computed Properties
    var selectedStar: Star2D? {
        guard let selectedStarID = selectedStarID else { return nil }
        return stars.first { $0.id == selectedStarID }
    }
    
    // MARK: - Canvas Manipulation Methods
    
    /// キャンバスの指定位置に星を追加する
    func addStar(at location: CGPoint, in frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let canvasRadius = frame.width / 2
        let relativePosition = CGPoint(x: location.x - center.x, y: location.y - center.y)
        let distance = sqrt(pow(relativePosition.x, 2) + pow(relativePosition.y, 2))

        // キャンバスの円内である場合のみ追加
        if distance <= canvasRadius {
            deselectStar()
            let newStar = Star2D(position: relativePosition, color: selectedColor, shape: .circle, size: selectedStarSize)
            stars.append(newStar)
        }
    }
    
    /// プレビューで表示されているパターンをキャンバスに適用する
    func applyPattern() {
        let newStars = previewStars.map {
            Star2D(position: $0.position, color: selectedColor, shape: $0.shape, size: selectedStarSize)
        }
        stars.append(contentsOf: newStars)
        previewStars.removeAll()
    }

    /// パターンツールの設定に基づいてプレビューを更新する
    func updatePreview(canvasSize: CGFloat) {
        previewStars.removeAll()
        guard selectedTool != .single && selectedTool != .eraser else { return }

        let radius = canvasSize / 2
        let previewColor = selectedColor.opacity(0.5)
        
        switch selectedTool {
        case .circle:
            let count = Int(2 * .pi * previewRadius / spacing)
            guard count > 0 else { return }
            for i in 0..<count {
                let angle = 2 * .pi * Double(i) / Double(count)
                let x = cos(angle) * previewRadius
                let y = sin(angle) * previewRadius
                previewStars.append(Star2D(position: CGPoint(x: x, y: y), color: previewColor, shape: .circle, size: selectedStarSize))
            }
        case .spiral:
            let maxRadius = radius * 0.9; let turns = 5
            guard spacing > 0 else { return }; let pointsPerTurn = Int(maxRadius / spacing) * 2
            guard pointsPerTurn > 0 else { return }
            for i in 0..<(turns * pointsPerTurn) {
                let angle = 2 * .pi * Double(i) / Double(pointsPerTurn)
                let currentRadius = maxRadius * Double(i) / Double(turns * pointsPerTurn)
                let x = cos(angle) * currentRadius; let y = sin(angle) * currentRadius
                if sqrt(x*x + y*y) <= maxRadius {
                    previewStars.append(Star2D(position: CGPoint(x: x, y: y), color: previewColor, shape: .circle, size: selectedStarSize))
                }
            }
        case .grid:
            let maxRadius = radius * 0.9
            guard spacing > 0 else { return }; let gridSize = Int(maxRadius / spacing)
            for x in -gridSize...gridSize {
                for y in -gridSize...gridSize {
                    let posX = Double(x) * spacing; let posY = Double(y) * spacing
                    if sqrt(posX * posX + posY * posY) <= maxRadius {
                         previewStars.append(Star2D(position: CGPoint(x: posX, y: posY), color: previewColor, shape: .circle, size: selectedStarSize))
                    }
                }
            }
        default: break
        }
    }
    
    /// 消しゴムツールで指定位置周辺の星を削除する
    func removeStars(at location: CGPoint, in frame: CGRect) {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let relativePosition = CGPoint(x: location.x - center.x, y: location.y - center.y)
        let eraserRadius: CGFloat = 20.0
        stars.removeAll { star in
            let distance = sqrt(pow(star.position.x - relativePosition.x, 2) + pow(star.position.y - relativePosition.y, 2))
            return distance <= eraserRadius
        }
    }
    
    // MARK: - Star Selection Methods
    
    /// 指定された星を選択状態にする
    func selectStar(_ star: Star2D) {
        selectedStarID = star.id
    }
    
    /// すべての星の選択を解除する
    func deselectStar() {
        selectedStarID = nil
    }
    
    /// 選択中の星の色を更新する
    func updateSelectedStarColor(newColor: Color) {
        guard let selectedStarID = selectedStarID,
              let index = stars.firstIndex(where: { $0.id == selectedStarID }) else { return }
        stars[index].color = newColor
    }
    
    /// 選択中の星を削除する
    func deleteSelectedStar() {
        guard let selectedStarID = selectedStarID else { return }
        stars.removeAll { $0.id == selectedStarID }
        self.selectedStarID = nil
    }
    
    // MARK: - Save and Clear Methods
    
    /// 現在のキャンバスの状態からFireworkShellオブジェクトを生成し、状態をリセットする
    func createAndClearShell() -> FireworkShell2D? {
        guard !fireworkName.isEmpty else { return nil }
        
        let shell = FireworkShell2D(name: fireworkName, stars: stars, shellRadius: 50.0)
        
        // キャンバスと名前をクリア
        clearCanvas()
        fireworkName = ""
        
        return shell
    }
    
    /// キャンバス上のすべての星を削除し、選択状態を解除する
    func clearCanvas() {
        stars.removeAll()
        selectedStarID = nil
    }
}

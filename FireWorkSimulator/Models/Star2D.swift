// Models/Star2D.swift

import SwiftUI

// MARK: - Codable Helpers
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)

        self.red = Double(r)
        self.green = Double(g)
        self.blue = Double(b)
        self.alpha = Double(a)
    }

    // 保存されたRGBA値からColorを復元するためのプロパティ
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}



// MARK: - Data Models
enum StarShape: String, Codable {
    case circle
    // 必要であれば他の形を追加できます e.g., case star
}

struct Star2D: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    private var codableColor: CodableColor // Codable準拠のためにヘルパーを使用
    var shape: StarShape
    var size: CGFloat

    /// `Star2D`の色。外部からはこのプロパティを通じて安全にアクセスします。
    var color: Color {
        get { codableColor.color }
        set { codableColor = CodableColor(color: newValue) }
    }

    // Codableが内部プロパティを正しく認識するためのキー
    enum CodingKeys: String, CodingKey {
        case id, position, codableColor, shape, size
    }

    /// 新しい星(Star2D)を生成します。
    /// - Parameters:
    ///   - id: 固有のID。デフォルトで自動生成されます。
    ///   - position: キャンバスの中心を(0,0)とした相対座標。
    ///   - color: 星の色。
    ///   - shape: 星の形。
    ///   - size: 星の直径。
    init(id: UUID = UUID(), position: CGPoint, color: Color, shape: StarShape, size: CGFloat) {
        self.id = id
        self.position = position
        self.codableColor = CodableColor(color: color)
        self.shape = shape
        self.size = size
    }
}

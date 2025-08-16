import SwiftUI

// MARK: - Codable Helpers
// SwiftUIのColor型をCodableにするためのヘルパー
// 内部でUIColorに変換し、信頼性の高いRGBA値を取得して保存します。
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

// CoreGraphicsのCGPoint型をCodableにするための拡張
extension CGPoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
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

    /// 新しい星（Star2D）を生成します。
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

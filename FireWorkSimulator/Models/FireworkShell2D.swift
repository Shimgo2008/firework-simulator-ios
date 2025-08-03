import SwiftUI

struct FireworkShell2D: Codable {
    var name: String
    var stars: [Star2D]
    var shellRadius: CGFloat
    var is3DMode: Bool = false // 断面図/立体感の設定（デフォルトは断面図優先）
} 
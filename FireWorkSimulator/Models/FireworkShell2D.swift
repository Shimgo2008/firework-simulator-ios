import SwiftUI

struct FireworkShell2D: Codable, Identifiable {
    var id = UUID()
    var name: String
    var stars: [Star2D]
    var shellRadius: CGFloat
}

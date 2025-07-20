import SwiftUI

enum StarShape: String, Codable {
    case circle, star
}

struct Star2D: Identifiable, Codable {
    let id: UUID
    var position: CGPoint
    var color: Color
    var shape: StarShape
    
    // Codable対応のためのカスタムコーディング
    enum CodingKeys: String, CodingKey {
        case id, positionX, positionY, colorRed, colorGreen, colorBlue, colorAlpha, shape
    }
    
    init(id: UUID = UUID(), position: CGPoint, color: Color, shape: StarShape) {
        self.id = id
        self.position = position
        self.color = color
        self.shape = shape
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let x = try container.decode(CGFloat.self, forKey: .positionX)
        let y = try container.decode(CGFloat.self, forKey: .positionY)
        position = CGPoint(x: x, y: y)
        
        let red = try container.decode(Double.self, forKey: .colorRed)
        let green = try container.decode(Double.self, forKey: .colorGreen)
        let blue = try container.decode(Double.self, forKey: .colorBlue)
        let alpha = try container.decode(Double.self, forKey: .colorAlpha)
        color = Color(red: red, green: green, blue: blue, opacity: alpha)
        
        shape = try container.decode(StarShape.self, forKey: .shape)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(position.x, forKey: .positionX)
        try container.encode(position.y, forKey: .positionY)
        
        // ColorをRGB値に変換（iOS 15以降対応）
        let resolvedColor = color.resolve(in: EnvironmentValues())
        try container.encode(Double(resolvedColor.red), forKey: .colorRed)
        try container.encode(Double(resolvedColor.green), forKey: .colorGreen)
        try container.encode(Double(resolvedColor.blue), forKey: .colorBlue)
        try container.encode(Double(resolvedColor.opacity), forKey: .colorAlpha)
        
        try container.encode(shape, forKey: .shape)
    }
}

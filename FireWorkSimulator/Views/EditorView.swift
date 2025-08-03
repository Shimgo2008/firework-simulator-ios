import SwiftUI

struct EditorView: View {
    @StateObject private var viewModel = ShellViewModel()
    @State private var shellRadius: CGFloat = 50.0
    @State private var selectedColor: Color = .red
    @State private var selectedTool: StarTool = .single
    @State private var starSize: CGFloat = 6.0
    @State private var spacing: CGFloat = 10.0
    @State private var stars: [Star2D] = []
    @State private var selectedStar: Star2D?
    @State private var circleRadius: CGFloat = 80.0
    @State private var isDraggingCircle: Bool = false
    @State private var previewRadius: CGFloat = 80.0
    @State private var showSaveAlert: Bool = false
    @State private var fireworkName: String = ""
    @State private var is3DMode: Bool = false // 断面図/立体感のトグル
    
    enum StarTool: String, CaseIterable {
        case single, eraser, circle, spiral, grid
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // メインキャンバスエリア
                ZStack {
                    // 背景画像
                    if let _ = UIImage(named: "editor_background") {
                        Image("editor_background")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } else {
                        // フォールバック背景
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                    }
                    
                    // 花火玉の断面図（外側の円）
                    Circle()
                        .fill(outerCircleColor)
                        .frame(width: 300, height: 300)
                    
                    // 花火玉の断面図（内側の円）
                    Circle()
                        .fill(Color.black)
                        .frame(width: 270, height: 270)
                    
                    // 円形配置のガイドライン
                    if selectedTool == .circle && isDraggingCircle {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: previewRadius * 2, height: previewRadius * 2)
                    }
                    
                    // 星（火薬）を配置するレイヤー
                    ZStack {
                        // 配置された星を表示
                        ForEach(stars) { star in
                            let isSelected = selectedStar?.id == star.id
                            StarView(star: star, isSelected: isSelected, starSize: starSize)
                                .onTapGesture {
                                    selectedStar = star
                                }
                                .onLongPressGesture {
                                    if let index = stars.firstIndex(where: { $0.id == star.id }) {
                                        stars.remove(at: index)
                                        selectedStar = nil
                                    }
                                }
                        }
                    }
                    .frame(width: 270, height: 270)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        addStar(at: location)
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if selectedTool == .circle {
                                    handleCircleDrag(value)
                                }
                            }
                            .onEnded { _ in
                                if selectedTool == .circle {
                                    isDraggingCircle = false
                                    // ドラッグ終了時に星をプロット
                                    applyCirclePlacement()
                                }
                            }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // 下部ツールバー（ぎゅぎゅっとまとめた）
                VStack(spacing: 8) {
                    // 断面図/立体感トグル
                    HStack {
                        Text("表示モード:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Toggle("", isOn: $is3DMode)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .labelsHidden()
                        
                        Text(is3DMode ? "立体感優先" : "断面図優先")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    
                    // 星配置ツール
                    HStack {
                        Text("配置ツール:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        ForEach(StarTool.allCases, id: \.self) { tool in
                            let isSelected = selectedTool == tool
                            let isCircle = tool == .circle
                            let shouldApplyPattern = tool != .single && tool != .eraser
                            
                            Button(action: {
                                selectedTool = tool
                                if isCircle {
                                    isDraggingCircle = true
                                } else if shouldApplyPattern {
                                    applyPatternPlacement()
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Image(systemName: toolIcon(for: tool))
                                        .font(.system(size: 16))
                                    Text(toolName(for: tool))
                                        .font(.caption2)
                                }
                                .foregroundColor(isSelected ? .blue : .gray)
                                .frame(width: 50, height: 40)
                                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    // 設定パネル
                    HStack(spacing: 16) {
                        // 星のサイズと間隔（上下に並べる）
                        VStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("星サイズ")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                HStack(spacing: 4) {
                                    ForEach([3, 6, 9, 12, 15, 18], id: \.self) { size in
                                        let isSelected = starSize == CGFloat(size)
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: CGFloat(size), height: CGFloat(size))
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                            )
                                            .onTapGesture {
                                                starSize = CGFloat(size)
                                            }
                                    }
                                }
                            }
                            
                            VStack(spacing: 2) {
                                Text("間隔")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                HStack {
                                    Text("\(Int(spacing))")
                                        .font(.caption)
                                        .frame(width: 30)
                                    Slider(value: $spacing, in: 5...50, step: 1)
                                        .frame(width: 80)
                                        .onChange(of: spacing) { _ in
                                            if selectedTool != .single && selectedTool != .eraser {
                                                applyPatternPlacement()
                                            }
                                        }
                                }
                            }
                        }
                        
                        // カラーパレット（半分で上下に並べる）
                        VStack(spacing: 8) {
                            VStack(spacing: 2) {
                                Text("カラー")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                HStack(spacing: 4) {
                                    ForEach(presetColors.prefix(4), id: \.self) { color in
                                        let isSelected = selectedColor == color
                                        Circle()
                                            .fill(color)
                                            .frame(width: 20, height: 20)
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                            )
                                            .onTapGesture {
                                                selectedColor = color
                                            }
                                    }
                                }
                            }
                            
                            HStack(spacing: 4) {
                                ForEach(presetColors.dropFirst(4).prefix(4), id: \.self) { color in
                                    let isSelected = selectedColor == color
                                    Circle()
                                        .fill(color)
                                        .frame(width: 20, height: 20)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            selectedColor = color
                                        }
                                }
                                ColorPicker("", selection: $selectedColor)
                                    .labelsHidden()
                                    .frame(width: 20, height: 20)
                            }
                        }
                        
                        Spacer()
                        
                        // 操作ボタン
                        VStack(spacing: 4) {
                            Button("クリア") {
                                stars.removeAll()
                                selectedStar = nil
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(4)
                            .font(.caption)
                            
                            Button("保存") {
                                showSaveAlert = true
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
            }
            .navigationTitle("花火玉エディタ")
            .navigationBarTitleDisplayMode(.inline)
            .alert("花火玉を保存", isPresent: $showSaveAlert) {
                TextField("花火玉の名前", text: $fireworkName)
                Button("キャンセル", role: .cancel) { }
                Button("保存") {
                    saveFireworkShell()
                }
            } message: {
                Text("花火玉に名前をつけて保存してください")
            }
        }
    }
    
    private var presetColors: [Color] {
        [
            .black, .gray, .blue, .white, .gray,
            .cyan, .green, .red, .brown, .green,
            .red, .orange, .yellow, .purple, .pink,
            .pink, .purple, .purple
        ]
    }
    
    private var outerCircleColor: Color {
        Color(
            red: 232 / 255,
            green: 165 / 255,
            blue: 71 / 255
        )
    }
    
    private func toolIcon(for tool: StarTool) -> String {
        switch tool {
        case .single: return "circle.fill"
        case .eraser: return "eraser"
        case .circle: return "circle.dashed"
        case .spiral: return "sparkles"
        case .grid: return "grid"
        }
    }
    
    private func toolName(for tool: StarTool) -> String {
        switch tool {
        case .single: return "単発"
        case .eraser: return "消しゴム"
        case .circle: return "円形"
        case .spiral: return "螺旋"
        case .grid: return "格子"
        }
    }
    
    private func addStar(at location: CGPoint) {
        // キャンバス中心からの相対位置に変換
        let center = CGPoint(x: 135, y: 135) // 270x270の中心
        let relativePosition = CGPoint(
            x: location.x - center.x,
            y: location.y - center.y
        )
        
        // 円の範囲内かチェック
        let distance = sqrt(relativePosition.x * relativePosition.x + relativePosition.y * relativePosition.y)
        if distance <= 135 { // 半径135px以内
            if selectedTool == .eraser {
                // 消しゴムモード：近くの星を削除
                removeNearbyStars(at: relativePosition)
            } else {
                // 通常モード：星を追加
                let newStar = Star2D(
                    position: relativePosition,
                    color: selectedColor,
                    shape: .circle
                )
                stars.append(newStar)
            }
        }
    }
    
    private func removeNearbyStars(at position: CGPoint) {
        let eraserRadius: CGFloat = 20.0
        stars.removeAll { star in
            let distance = sqrt(
                pow(star.position.x - position.x, 2) + 
                pow(star.position.y - position.y, 2)
            )
            return distance <= eraserRadius
        }
    }
    
    private func handleCircleDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: 135, y: 135)
        let dragLocation = value.location
        let distance = sqrt(
            pow(dragLocation.x - center.x, 2) + 
            pow(dragLocation.y - center.y, 2)
        )
        
        // ドラッグで半径を更新（プレビューのみ）
        previewRadius = min(max(distance, 20), 120)
        
        // ドラッグ開始時にガイドラインを表示
        isDraggingCircle = true
        
        // リアルタイム更新は削除（ラグ防止）
    }
    
    private func applyPatternPlacement() {
        stars.removeAll()
        
        switch selectedTool {
        case .circle:
            applyCirclePlacement()
        case .spiral:
            applySpiralPlacement()
        case .grid:
            applyGridPlacement()
        case .single, .eraser:
            break
        }
    }
    
    private func applyCirclePlacement() {
        let radius = previewRadius
        let count = Int(2 * .pi * radius / spacing)
        for i in 0..<count {
            let angle = 2 * .pi * Double(i) / Double(count)
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            let star = Star2D(
                position: CGPoint(x: x, y: y),
                color: selectedColor,
                shape: .circle
            )
            stars.append(star)
        }
    }
    
    private func applySpiralPlacement() {
        let radius = 120.0
        let turns = 5
        let pointsPerTurn = Int(radius / spacing)
        for i in 0..<(turns * pointsPerTurn) {
            let angle = 2 * .pi * Double(i) / Double(pointsPerTurn)
            let currentRadius = radius * Double(i) / Double(turns * pointsPerTurn)
            let x = cos(angle) * currentRadius
            let y = sin(angle) * currentRadius
            let star = Star2D(
                position: CGPoint(x: x, y: y),
                color: selectedColor,
                shape: .circle
            )
            stars.append(star)
        }
    }
    
    private func applyGridPlacement() {
        let radius = 120.0
        let gridSize = Int(radius * 2 / spacing)
        for x in -gridSize...gridSize {
            for y in -gridSize...gridSize {
                let posX = Double(x) * spacing
                let posY = Double(y) * spacing
                let distance = sqrt(posX * posX + posY * posY)
                if distance <= radius {
                    let star = Star2D(
                        position: CGPoint(x: posX, y: posY),
                        color: selectedColor,
                        shape: .circle
                    )
                    stars.append(star)
                }
            }
        }
    }
    
    private func saveFireworkShell() {
        if !fireworkName.isEmpty {
            let shell = FireworkShell2D(
                name: fireworkName,
                stars: stars,
                shellRadius: shellRadius,
                is3DMode: is3DMode // 3Dモード設定を保存
            )
            viewModel.addShell(shell)
            stars.removeAll()
            selectedStar = nil
            fireworkName = ""
        }
    }
}

struct StarView: View {
    let star: Star2D
    let isSelected: Bool
    let starSize: CGFloat
    
    var body: some View {
        Circle()
            .fill(star.color)
            .frame(width: starSize, height: starSize)
            .position(x: star.position.x + 135, y: star.position.y + 135)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    .frame(width: starSize + 4, height: starSize + 4)
            )
    }
}

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView()
    }
} 

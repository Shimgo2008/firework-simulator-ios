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
    @State private var is3DMode: Bool = false

    enum StarTool: String, CaseIterable {
        case single, eraser, circle, spiral, grid
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                canvasView
                toolbarView
            }
            .navigationTitle("花火玉エディタ")
            .navigationBarTitleDisplayMode(.inline)
            .alert("花火玉を保存", isPresented: $showSaveAlert) {
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

    // MARK: - Subviews

    private var canvasView: some View {
        ZStack {
            if let _ = UIImage(named: "editor_background") {
                Image("editor_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle().fill(Color.gray.opacity(0.1))
            }

            Circle().fill(outerCircleColor).frame(width: 300, height: 300)
            Circle().fill(Color.black).frame(width: 270, height: 270)

            if selectedTool == .circle && isDraggingCircle {
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(width: previewRadius * 2, height: previewRadius * 2)
            }

            ZStack {
                ForEach(stars) { star in
                    let isSelected = selectedStar?.id == star.id
                    StarView(star: star, isSelected: isSelected, starSize: starSize)
                        .onTapGesture { selectedStar = star }
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
                        if selectedTool == .circle { handleCircleDrag(value) }
                    }
                    .onEnded { _ in
                        if selectedTool == .circle {
                            isDraggingCircle = false
                            applyCirclePlacement()
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbarView: some View {
        VStack(spacing: 8) {
            displayModeToggle
            toolPicker
            settingsPanel
        }
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }

    private var displayModeToggle: some View {
        HStack {
            Text("表示モード:").font(.caption).foregroundColor(.gray)
            Toggle("", isOn: $is3DMode).toggleStyle(SwitchToggleStyle(tint: .blue)).labelsHidden()
            Text(is3DMode ? "立体感優先" : "断面図優先").font(.caption).foregroundColor(.gray)
            Spacer()
        }
        .padding(.horizontal, 8)
    }

    private var toolPicker: some View {
        HStack {
            Text("配置ツール:").font(.caption).foregroundColor(.gray)
            ForEach(StarTool.allCases, id: \.self) { tool in
                Button(action: {
                    selectedTool = tool
                    if tool == .circle {
                        isDraggingCircle = true
                    } else if shouldApplyPattern() {
                        applyPatternPlacement()
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: toolIcon(for: tool)).font(.system(size: 16))
                        Text(toolName(for: tool)).font(.caption2)
                    }
                    .foregroundColor(selectedTool == tool ? .blue : .gray)
                    .frame(width: 50, height: 40)
                    .background(selectedTool == tool ? Color.blue.opacity(0.2) : Color.clear)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    private var settingsPanel: some View {
        HStack(spacing: 16) {
            starSettings
            colorPalette
            Spacer()
            actionButtons
        }
        .padding(.horizontal, 8)
    }

    private var starSettings: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("星サイズ").font(.caption2).foregroundColor(.gray)
                HStack(spacing: 4) {
                    ForEach([3, 6, 9, 12, 15, 18], id: \.self) { size in
                        let isSelected = starSize == CGFloat(size)
                        Circle().fill(Color.black).frame(width: CGFloat(size), height: CGFloat(size))
                            .overlay(Circle().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1))
                            .onTapGesture { starSize = CGFloat(size) }
                    }
                }
            }
            VStack(spacing: 2) {
                Text("間隔").font(.caption2).foregroundColor(.gray)
                HStack {
                    Text("\(Int(spacing))").font(.caption).frame(width: 30)
                    Slider(value: $spacing, in: 5...50, step: 1).frame(width: 80)
                        .onChange(of: spacing) { _ in
                            if shouldApplyPattern() { applyPatternPlacement() }
                        }
                }
            }
        }
    }

    private var colorPalette: some View {
        VStack(spacing: 8) {
            VStack(spacing: 2) {
                Text("カラー").font(.caption2).foregroundColor(.gray)
                HStack(spacing: 4) {
                    ForEach(presetColors.prefix(4), id: \.self) { color in
                        colorCircle(for: color)
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(presetColors.dropFirst(4).prefix(4), id: \.self) { color in
                    colorCircle(for: color)
                }
                ColorPicker("", selection: $selectedColor).labelsHidden().frame(width: 20, height: 20)
            }
        }
    }
    
    private func colorCircle(for color: Color) -> some View {
        let isSelected = selectedColor == color
        return Circle()
            .fill(color)
            .frame(width: 20, height: 20)
            .overlay(Circle().stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1))
            .onTapGesture { selectedColor = color }
    }

    private var actionButtons: some View {
        VStack(spacing: 4) {
            Button("クリア") {
                stars.removeAll()
                selectedStar = nil
            }
            .buttonStyle(EditorButtonStyle(backgroundColor: .red.opacity(0.2), foregroundColor: .red))
            
            Button("保存") { showSaveAlert = true }
            .buttonStyle(EditorButtonStyle(backgroundColor: .blue, foregroundColor: .white, horizontalPadding: 12, verticalPadding: 6))
        }
    }
    
    // MARK: - Helper Properties

    private var presetColors: [Color] {
        [.black, .gray, .blue, .white, .cyan, .green, .red, .orange, .yellow, .purple, .pink]
    }

    private var outerCircleColor: Color {
        Color(red: 232 / 255, green: 165 / 255, blue: 71 / 255)
    }

    // MARK: - Functions

    private func shouldApplyPattern() -> Bool {
        return selectedTool != .single && selectedTool != .eraser
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
        let center = CGPoint(x: 135, y: 135)
        let relativePosition = CGPoint(x: location.x - center.x, y: location.y - center.y)
        let distance = sqrt(relativePosition.x * relativePosition.x + relativePosition.y * relativePosition.y)

        if distance <= 135 {
            if selectedTool == .eraser {
                removeNearbyStars(at: relativePosition)
            } else {
                stars.append(Star2D(position: relativePosition, color: selectedColor, shape: .circle))
            }
        }
    }

    private func removeNearbyStars(at position: CGPoint) {
        let eraserRadius: CGFloat = 20.0
        stars.removeAll { star in
            let distance = sqrt(pow(star.position.x - position.x, 2) + pow(star.position.y - position.y, 2))
            return distance <= eraserRadius
        }
    }

    private func handleCircleDrag(_ value: DragGesture.Value) {
        let center = CGPoint(x: 135, y: 135)
        let dragLocation = value.location
        let distance = sqrt(pow(dragLocation.x - center.x, 2) + pow(dragLocation.y - center.y, 2))
        previewRadius = min(max(distance, 20), 120)
        isDraggingCircle = true
    }

    private func applyPatternPlacement() {
        stars.removeAll()
        switch selectedTool {
        case .circle: applyCirclePlacement()
        case .spiral: applySpiralPlacement()
        case .grid: applyGridPlacement()
        case .single, .eraser: break
        }
    }

    private func applyCirclePlacement() {
        let radius = previewRadius
        let count = Int(2 * .pi * radius / spacing)
        for i in 0..<count {
            let angle = 2 * .pi * Double(i) / Double(count)
            let x = cos(angle) * radius
            let y = sin(angle) * radius
            stars.append(Star2D(position: CGPoint(x: x, y: y), color: selectedColor, shape: .circle))
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
            stars.append(Star2D(position: CGPoint(x: x, y: y), color: selectedColor, shape: .circle))
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
                    stars.append(Star2D(position: CGPoint(x: posX, y: posY), color: selectedColor, shape: .circle))
                }
            }
        }
    }

    private func saveFireworkShell() {
        if !fireworkName.isEmpty {
            let shell = FireworkShell2D(name: fireworkName, stars: stars, shellRadius: shellRadius, is3DMode: is3DMode)
            viewModel.addShell(shell)
            stars.removeAll()
            selectedStar = nil
            fireworkName = ""
        }
    }
}

// MARK: - Reusable Components

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

struct EditorButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 4
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Preview

struct EditorView_Previews: PreviewProvider {
    static var previews: some View {
        EditorView()
    }
}

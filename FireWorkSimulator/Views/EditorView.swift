import SwiftUI

struct EditorView: View {

    // ShellListViewから渡される、一覧を管理するViewModel
    @ObservedObject var shellListViewModel: ShellListViewModel

    // このView内だけで使う、エディタの状態を管理するViewModel
    @StateObject private var editorViewModel = EditorViewModel()

    @Environment(\.presentationMode) var presentationMode

    private let canvasSize: CGFloat = 300
    private var canvasRadius: CGFloat { canvasSize / 2 }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            canvasView
            Spacer()
            settingsPanelView
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("花火玉エディタ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { navigationBarItems }
        .alert("花火玉を保存", isPresented: $editorViewModel.showSaveAlert) { saveAlertView } message: {
            Text("花火玉に名前をつけて保存してください")
        }
        .alert("キャンバスをクリア", isPresented: $editorViewModel.showClearAlert) { clearAlertView } message: {
            Text("すべての星を削除しますか？この操作は取り消せません。")
        }
        .interactiveDismissDisabled()
    }

    // MARK: - Canvas View
    private var canvasView: some View {
        ZStack {
            Circle().fill(Color(red: 232/255, green: 165/255, blue: 71/255))
            Circle().fill(Color.black).frame(width: canvasSize, height: canvasSize)

            ForEach(editorViewModel.stars) { star in
                StarShapeView(star: star, isSelected: editorViewModel.selectedStarID == star.id, canvasRadius: canvasRadius)
                    .onTapGesture { editorViewModel.selectStar(star) }
            }
            
            ForEach(editorViewModel.previewStars) { star in
                StarShapeView(star: star, isSelected: false, canvasRadius: canvasRadius)
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .contentShape(Rectangle())
        .onTapGesture { location in handleCanvasTap(at: location) }
        // このwarnは無視して大丈夫
        .onChange(of: editorViewModel.selectedTool) { _ in editorViewModel.updatePreview(canvasSize: canvasSize) }
        .onChange(of: editorViewModel.spacing) { _ in editorViewModel.updatePreview(canvasSize: canvasSize) }
        .onChange(of: editorViewModel.previewRadius) { _ in editorViewModel.updatePreview(canvasSize: canvasSize) }
        .onChange(of: editorViewModel.selectedColor) { _ in editorViewModel.updatePreview(canvasSize: canvasSize) }
        .onChange(of: editorViewModel.selectedStarSize) { _ in editorViewModel.updatePreview(canvasSize: canvasSize) }
    }

    // MARK: - Settings Panel
    @ViewBuilder
    private var settingsPanelView: some View {
        VStack(spacing: 16) {
            toolPickerView
            
            if editorViewModel.selectedStar != nil {
                selectedStarSettings
            } else {
                currentToolSettings
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
    
    // MARK: - Tool & Settings Subviews
    private var toolPickerView: some View {
        HStack(spacing: 8) {
            ForEach(EditorViewModel.StarTool.allCases) { tool in
                Button(action: { editorViewModel.selectedTool = tool }) {
                    VStack(spacing: 4) {
                        Image(systemName: toolIcon(for: tool)).font(.title3)
                        Text(toolName(for: tool)).font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(editorViewModel.selectedTool == tool ? .accentColor : .secondary)
                    .background(editorViewModel.selectedTool == tool ? Color.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var currentToolSettings: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("カラー").font(.caption).foregroundColor(.secondary)
                    colorPalette
                }
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text("星サイズ").font(.caption).foregroundColor(.secondary)
                    starSizePicker(selection: $editorViewModel.selectedStarSize)
                }
            }
            
            if editorViewModel.selectedTool != .single && editorViewModel.selectedTool != .eraser {
                patternSettings.padding(.top, 8)
                applyPatternButton.padding(.top, 8)
            }
        }
    }
    
    private var selectedStarSettings: some View {
        HStack {
            Text("選択中の星").font(.headline)
            Spacer()
            
            ColorPicker("カラー", selection: Binding(
                get: { editorViewModel.selectedStar?.color ?? .white },
                set: { editorViewModel.updateSelectedStarColor(newColor: $0) }
            ), supportsOpacity: false).labelsHidden()
            
            Button(role: .destructive) {
                editorViewModel.deleteSelectedStar()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var patternSettings: some View {
        switch editorViewModel.selectedTool {
        case .circle:
            patternSlider(title: "半径", value: $editorViewModel.previewRadius, range: 10...(canvasRadius * 0.9))
        case .spiral, .grid:
            patternSlider(title: "間隔", value: $editorViewModel.spacing, range: 10...50)
        default:
            EmptyView()
        }
    }
    
    private var colorPalette: some View {
        HStack {
            ForEach(presetColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(editorViewModel.selectedColor == color ? Color.accentColor : Color.clear, lineWidth: 2))
                    .onTapGesture { editorViewModel.selectedColor = color }
            }
            ColorPicker("", selection: $editorViewModel.selectedColor, supportsOpacity: false).labelsHidden()
        }
    }
    
    private func starSizePicker(selection: Binding<CGFloat>) -> some View {
        HStack {
            ForEach([6.0, 12.0, 18.0], id: \.self) { size in
                Circle()
                    .fill(Color.gray)
                    .frame(width: size + 4, height: size + 4)
                    .overlay(Circle().stroke(selection.wrappedValue == size ? Color.accentColor : Color.clear, lineWidth: 2))
                    .contentShape(Circle())
                    .onTapGesture { selection.wrappedValue = size }
            }
        }
    }

    private func patternSlider(title: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        VStack(spacing: 2) {
            Text("\(title): \(Int(value.wrappedValue))").font(.caption).foregroundColor(.secondary)
            Slider(value: value, in: range, step: 1)
        }
    }

    private var applyPatternButton: some View {
        Button(action: editorViewModel.applyPattern) {
            Text("パターンを配置").frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: - Navigation Bar Items & Alerts
    private var navigationBarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button("クリア", role: .destructive) { editorViewModel.showClearAlert = true }
            Button("保存") { editorViewModel.showSaveAlert = true }.buttonStyle(.borderedProminent)
        }
    }
    
    private var saveAlertView: some View {
        Group {
            TextField("花火玉の名前", text: $editorViewModel.fireworkName)
            Button("キャンセル", role: .cancel) { }
            Button("保存") {
                saveFireworkShell()
            }
        }
    }
    
    private var clearAlertView: some View {
        Group {
            Button("クリアする", role: .destructive) { editorViewModel.clearCanvas() }
            Button("キャンセル", role: .cancel) { }
        }
    }

    // MARK: - Helper Methods & Properties
    
    // 3. 保存ロジックを修正
    private func saveFireworkShell() {
        if !editorViewModel.fireworkName.isEmpty {
            let newShell = FireworkShell2D(
                name: editorViewModel.fireworkName,
                stars: editorViewModel.stars,
                shellRadius: 50.0
            )
            // 渡されてきたshellListViewModelを使って、一覧にデータを追加
            shellListViewModel.addShell(newShell)
            
            // 保存後、一覧画面に戻る
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    private func handleCanvasTap(at location: CGPoint) {
        let frame = CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize)
        switch editorViewModel.selectedTool {
        case .single: editorViewModel.addStar(at: location, in: frame)
        case .eraser: editorViewModel.removeStars(at: location, in: frame)
        default: editorViewModel.deselectStar()
        }
    }
    
    private var presetColors: [Color] {
        [.red, .orange, .yellow, .green, .blue, .purple, .white]
    }

    private func toolIcon(for tool: EditorViewModel.StarTool) -> String {
        switch tool {
        case .single: return "hand.tap"
        case .eraser: return "eraser"
        case .circle: return "circle.dashed"
        case .spiral: return "sparkles"
        case .grid: return "grid"
        }
    }

    private func toolName(for tool: EditorViewModel.StarTool) -> String {
        switch tool {
        case .single: return "単発"
        case .eraser: return "消しゴム"
        case .circle: return "円形"
        case .spiral: return "螺旋"
        case .grid: return "格子"
        }
    }
}

// MARK: - Reusable Star Shape View
struct StarShapeView: View {
    let star: Star2D
    let isSelected: Bool
    let canvasRadius: CGFloat

    var body: some View {
        let viewPosition = CGPoint(x: star.position.x + canvasRadius, y: star.position.y + canvasRadius)
        
        Circle()
            .fill(star.color)
            .frame(width: star.size, height: star.size)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    .frame(width: star.size + 6, height: star.size + 6)
            )
            .position(viewPosition)
    }
}

// MARK: - Custom View Modifier
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Preview
struct EditorView_Previews: PreviewProvider {
    static var previews: some View {

        NavigationView {
            EditorView(shellListViewModel: ShellListViewModel())
        }
    }
}

import SwiftUI

struct ShellListView: View {
    @StateObject private var viewModel = ShellViewModel()
    @State private var searchText: String = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var filteredShells: [(Int, FireworkShell2D)] {
        if searchText.isEmpty {
            return Array(viewModel.shells.enumerated())
        } else {
            return viewModel.shells.enumerated().filter { $0.element.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("花火玉名で検索", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding([.horizontal, .top])
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredShells, id: \.0) { (index, shell) in
                            ShellCardView(shell: shell, index: index, onDelete: {
                                withAnimation {
                                    viewModel.removeShell(at: index)
                                }
                            })
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("作成済み花火玉")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        viewModel.saveShellsToJSON()
                    }
                }
            }
        }
    }
}

struct ShellCardView: View {
    let shell: FireworkShell2D
    let index: Int
    let onDelete: () -> Void
    
    let cardWidth: CGFloat = 160
    @State private var offset: CGFloat = 0
    @State private var isSwiping: Bool = false
    
    var body: some View {
        VStack(spacing: 8) {
            // プレビューエリア
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .frame(height: 120)
                
                // 花火玉の断面図プレビュー
                ZStack {
                    // 外側の円
                    Circle()
                        .fill(Color(
                            red: 232/255,
                            green: 165/255,
                            blue: 71/255
                        ))
                        .frame(width: 80, height: 80)
                        .position(x: cardWidth/2, y: 60)
                    
                    // 内側の円
                    Circle()
                        .fill(Color.black)
                        .frame(width: 70, height: 70)
                        .position(x: cardWidth/2, y: 60)
                    
                    // 星のプレビュー
                    let previewCenter = CGPoint(x: cardWidth/2, y: 60)
                    let scale: CGFloat = 35.0 / 135.0
                    ForEach(shell.stars.prefix(20)) { star in
                        Circle()
                            .fill(star.color)
                            .frame(width: 3, height: 3)
                            .position(
                                x: previewCenter.x + star.position.x * scale,
                                y: previewCenter.y + star.position.y * scale
                            )
                    }
                }
            }
            
            // 情報エリア
            VStack(alignment: .leading, spacing: 4) {
                Text(shell.name.isEmpty ? "花火玉 \(index + 1)" : shell.name)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text("星: \(shell.stars.count)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("半径: \(String(format: "%.0f", shell.shellRadius))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: cardWidth)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
        .offset(x: offset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        offset = value.translation.width
                        isSwiping = true
                    }
                }
                .onEnded { value in
                    if value.translation.width < -60 {
                        onDelete()
                    }
                    offset = 0
                    isSwiping = false
                }
        )
    }
}

struct ShellListView_Previews: PreviewProvider {
    static var previews: some View {
        ShellListView()
    }
} 

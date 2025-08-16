import SwiftUI

struct ShellListView: View {
    // ViewModelを導入し、状態管理を委任
    @StateObject private var viewModel = ShellListViewModel()
    
    private let columns = [
        GridItem(.adaptive(minimum: 160)) // 画面サイズに応じて列数を調整
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.filteredShells) { shell in
                        ShellCardView(shell: shell)
                            // 長押しでコンテキストメニューを表示する方式に変更
                            .contextMenu {
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.removeShell(shell)
                                    }
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("作成済み花火玉")
            // iOS標準のモダンな検索バーに変更
            .searchable(text: $viewModel.searchText, prompt: "花火玉名で検索")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // EditorViewにViewModelを渡してデータフローを接続
                    NavigationLink(destination: EditorView(shellListViewModel: viewModel)) {
                        Image(systemName: "plus")
                    }
                }
            }
            // 花火玉がない場合にメッセージを表示
            .overlay {
                if viewModel.shells.isEmpty {
                    Text("まだ花火玉がありません\n右上の「+」から作成しましょう")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}

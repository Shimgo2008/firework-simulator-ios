//
//  P2PRoomView.swift
//  FireWorkSimulator
//
//  Created by 岩澤慎平 on 2025/09/25.
//

import SwiftUI
import MultipeerConnectivity

struct P2PRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // 1. @FocusState を使ってキーボードのフォーカスを管理
    @FocusState private var isTextFieldFocused: Bool

    // P2Pの状態管理
    @State private var groupName: String = ""
    @State private var isHosting = false
    @State private var connectedPeers: [String] = [] // 参加者リスト（仮）
    @State private var mode: Mode = .create // 作成 or 参加
    @State private var availableGroups: [String] = ["花火パーティー", "夏祭り"] // 仮の近くのグループ

    @State private var searchText: String = ""
    // 検索テキストでフィルタリングされたグループのリスト
    private var filteredGroups: [String] {
        if searchText.isEmpty {
            // 検索テキストが空の場合は、すべてのグループを表示
            return availableGroups
        } else {
            // 大文字・小文字を区別せずに、名前に検索テキストが含まれるものをフィルタリング
            return availableGroups.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    enum Mode: String, CaseIterable {
        case create = "作成"
        case join = "参加"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // --- モード選択ピッカー ---
                CustomModePicker(selectedMode: $mode)
                    .padding()

                // --- モードに応じたコンテンツ ---
                if mode == .create {
                    ScrollView {
                        VStack {
                            createGroupSection
                            if !connectedPeers.isEmpty {
                                participantsSection.padding(.top, 30)
                            }
                        }
                    }
                } else { // mode == .join
                    List {
                        ForEach(filteredGroups, id: \.self) { group in
                            HStack {
                                Text(group)
                                Spacer()
                                Button("参加") {
                                    if !connectedPeers.contains(group) {
                                        connectedPeers.append(group)
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if filteredGroups.isEmpty && !searchText.isEmpty {
                            Text("検索結果がありません")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            // 1. VStack全体に対して、条件付きでsearchableを適用する
            .searchableIf(mode == .join, text: $searchText, prompt: "グループを検索")
            .navigationTitle("P2Pグループ管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        isTextFieldFocused = false
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
        }
    }
    
    // MARK: - Subviews

    private var createGroupSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("グループ名")
                    .font(.headline)
                TextField("例: 花火パーティー", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused) // 4. TextFieldにFocusStateを紐付け
            }
            
            Button(action: {
                isTextFieldFocused = false // ボタンタップ時にもキーボードを閉じる
                isHosting.toggle()
                if isHosting {
                    connectedPeers.append("自分のデバイス")
                } else {
                    connectedPeers.removeAll()
                }
            }) {
                Text(isHosting ? "グループを閉じる" : "グループを作成")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isHosting ? Color.red : Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
    
    private var joinGroupSection: some View {
        VStack(alignment: .leading) {
            Text("近くのグループ")
                .font(.headline)
            ForEach(availableGroups, id: \.self) { group in
                HStack {
                    Text(group)
                    Spacer()
                    Button("参加") {
                        // 参加処理（仮）
                        connectedPeers.append(group)
                    }
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading) {
            Text("参加者 (\(connectedPeers.count))")
                .font(.headline)
            ForEach(connectedPeers, id: \.self) { peer in
                HStack {
                    Image(systemName: "person.circle")
                    Text(peer)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal)
    }
}
// MARK: - Custom Mode Picker

struct CustomModePicker: View {
    // 親Viewから受け取る選択中のモード
    @Binding var selectedMode: P2PRoomView.Mode
    // アニメーション用の名前空間
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(P2PRoomView.Mode.allCases, id: \.self) { mode in
                ZStack {
                    // 選択されているモードの時だけ背景カプセルを表示
                    if selectedMode == mode {
                        Capsule()
                            .fill(Color.blue)
                            .matchedGeometryEffect(id: "picker_background", in: animation)
                    }

                    Text(mode.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(selectedMode == mode ? .white : .primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .contentShape(Capsule()) // タップ領域をカプセルの形に
                .onTapGesture {
                    // タップされたら、アニメーション付きで選択モードを更新
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                }
            }
        }
        .padding(4)
        .background(
            Capsule().fill(Color(UIColor.secondarySystemBackground))
        )
        .padding(.horizontal)
    }
}
extension View {
    /// 条件がtrueの場合にのみ、searchableモディファイアを適用する
    @ViewBuilder
    func searchableIf(_ condition: Bool, text: Binding<String>, prompt: String) -> some View {
        if condition {
            self.searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(prompt))
        } else {
            self
        }
    }
}
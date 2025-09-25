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
    @FocusState private var isTextFieldFocused: Bool
    
    // 1. @StateObjectの代わりに@EnvironmentObjectでP2PManagerを受け取る
    @EnvironmentObject var p2pManager: P2PManager

    // --- UI制御用のState ---
    @State private var groupName: String = "" // グループ名入力用
    @State private var mode: Mode = .create   // 作成 or 参加 モード
    @State private var searchText: String = "" // グループ検索用

    enum Mode: String, CaseIterable {
        case create = "作成"
        case join = "参加"
    }

    // 検索テキストでフィルタリングされたグループのリスト
    private var filteredGroups: [String] {
        if searchText.isEmpty {
            return p2pManager.availableGroups
        } else {
            return p2pManager.availableGroups.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
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
                            if !p2pManager.connectedPeers.isEmpty || p2pManager.currentGroupName != nil {
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
                                    p2pManager.joinGroup(name: group)
                                }
                                .buttonStyle(.bordered)
                                // 既に接続済みの場合はボタンを無効化
                                .disabled(p2pManager.currentGroupName != nil)
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
            // 2. ビューが表示された時に、既に入力されているグループ名を反映
            .onAppear {
                if let name = p2pManager.currentGroupName {
                    groupName = name
                }
            }
        }
        // 3. .onDisappearでのleaveGroup()呼び出しは削除
    }
    
    // MARK: - Subviews

    private var createGroupSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("グループ名")
                    .font(.headline)
                TextField("例: 花火パーティー", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    // グループ参加中は編集不可に
                    .disabled(p2pManager.currentGroupName != nil)
            }
            
            Button(action: {
                isTextFieldFocused = false
                if p2pManager.currentGroupName == nil {
                    guard !groupName.isEmpty else { return }
                    p2pManager.createGroup(name: groupName)
                } else {
                    p2pManager.leaveGroup()
                    groupName = ""
                }
            }) {
                Text(p2pManager.currentGroupName == nil ? "グループを作成" : "グループを閉じる")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(p2pManager.currentGroupName == nil ? Color.blue : Color.red)
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading) {
            Text("参加者 (\(p2pManager.connectedPeers.count + 1))") // 自分(+1)
                .font(.headline)
            
            HStack {
                Image(systemName: "person.circle.fill")
                Text("自分 (\(UIDevice.current.name))")
            }
            .padding(.vertical, 4)
            
            ForEach(p2pManager.connectedPeers, id: \.self) { peer in
                HStack {
                    Image(systemName: "person.circle")
                    Text(peer.displayName)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Custom UI Components (同梱)

struct CustomModePicker: View {
    @Binding var selectedMode: P2PRoomView.Mode
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(P2PRoomView.Mode.allCases, id: \.self) { mode in
                ZStack {
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
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedMode = mode
                    }
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
    }
}

// MARK: - View Extension (同梱)

extension View {
    @ViewBuilder
    func searchableIf(_ condition: Bool, text: Binding<String>, prompt: String) -> some View {
        if condition {
            self.searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(prompt))
        } else {
            self
        }
    }
}
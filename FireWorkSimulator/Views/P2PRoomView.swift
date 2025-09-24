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

    enum Mode: String, CaseIterable {
        case create = "作成"
        case join = "参加"
    }
    
    var body: some View {
        NavigationView {
            // 画面全体をタップした時にキーボードを閉じるため、ZStackやColor.clearを使用
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isTextFieldFocused = false
                    }
                
                ScrollView {
                    VStack(spacing: 30) { // spacingを調整
                        // モード選択
                        Picker("モード", selection: $mode) {
                            ForEach(Mode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        if mode == .create {
                            // グループ作成UI
                            createGroupSection
                        } else {
                            // グループ参加UI
                            joinGroupSection
                        }
                        
                        // 参加者リスト（共通）
                        if !connectedPeers.isEmpty {
                            participantsSection
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("P2Pグループ管理")
            // 2. 最新の .toolbar Modifier を使用
            .toolbar {
                // ナビゲーションバー右上の「完了」ボタン
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                // 3. キーボード用のツールバーを追加
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer() // ボタンを右寄せにする
                    Button("完了") {
                        isTextFieldFocused = false // フォーカスを外してキーボードを閉じる
                    }
                }
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

// MARK: - Preview
struct P2PRoomView_Previews: PreviewProvider {
    static var previews: some View {
        P2PRoomView()
    }
}
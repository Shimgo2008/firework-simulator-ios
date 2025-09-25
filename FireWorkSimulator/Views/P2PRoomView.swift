//
//  P2PRoomView.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/09/25.
//

import SwiftUI
import MultipeerConnectivity

struct P2PRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @FocusState private var isTextFieldFocused: Bool
    
    @EnvironmentObject var p2pManager: P2PManager

    @State private var groupName: String = ""
    @State private var mode: Mode = .create
    @State private var searchText: String = ""
    @State private var joiningGroup: String? = nil // 参加中のグループ名

    enum Mode: String, CaseIterable {
        case create = "作成"
        case join = "参加"
    }

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
                CustomModePicker(selectedMode: $mode)
                    .padding()

                if mode == .create {
                    ScrollView {
                        VStack {
                            createGroupSection
                            if !p2pManager.connectedPeers.isEmpty || p2pManager.currentGroupName != nil {
                                participantsSection.padding(.top, 30)
                            }
                            // 接続状態を表示
                            if p2pManager.isConnected {
                                Text("接続中: \(p2pManager.connectedPeers.count + 1)人")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                    .padding(.top)
                            }
                        }
                    }
                } else { // mode == .join
                    List {
                        ForEach(filteredGroups, id: \.self) { group in
                            HStack {
                                Text(group)
                                Spacer()
                                if p2pManager.currentGroupName == group {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("参加中")
                                        .foregroundColor(.green)
                                } else if joiningGroup == group {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                    Text("参加中...")
                                        .foregroundColor(.blue)
                                } else {
                                    Button("参加") {
                                        joiningGroup = group
                                        p2pManager.joinGroup(name: group)
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(p2pManager.currentGroupName != nil || joiningGroup != nil)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if filteredGroups.isEmpty && !searchText.isEmpty {
                            Text("検索結果がありません")
                                .foregroundColor(.secondary)
                        } else if p2pManager.isConnected {
                            Text("既にグループに参加しています")
                                .foregroundColor(.green)
                        }
                    }
                }
                Spacer()
            }
            .searchableIf(mode == .join, text: $searchText, prompt: "グループを検索")
            .navigationTitle("P2Pグループ管理")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            p2pManager.reload()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        Button("完了") {
                            presentationMode.wrappedValue.dismiss()
                        }
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
            .onAppear {
                if let name = p2pManager.currentGroupName {
                    groupName = name
                }
            }
            .onChange(of: p2pManager.isConnected) { isConnected in
                if isConnected {
                    joiningGroup = nil // 接続成功したらリセット
                } else if !isConnected && joiningGroup != nil {
                    // 接続失敗したらリセット（タイムアウトなど）
                    joiningGroup = nil
                }
            }
        }
    }
    
    private var createGroupSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text("グループ名")
                    .font(.headline)
                TextField("例: 花火パーティー", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
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
            Text("参加者 (\(p2pManager.connectedPeers.count + 1))")
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

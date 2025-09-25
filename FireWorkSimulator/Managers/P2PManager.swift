//
//  P2PManager.swift
//  FireWorkSimulator
//
//  Created by shimgo on 2025/09/25.
//

import MultipeerConnectivity
import Combine

class P2PManager: NSObject, ObservableObject {
    // MARK: - Published Properties (UIでバインド)
    @Published var availableGroups: [String] = []  // 近くで見つけたグループリスト
    @Published var connectedPeers: [MCPeerID] = []  // 接続中の参加者
    @Published var isConnected: Bool = false  // 接続状態
    @Published var currentGroupName: String?  // 現在のグループ名
    
    // MARK: - Public Properties
    var groupOrigin: SIMD3<Float>? { groupOriginPrivate }
    
    // MARK: - Private Properties
    private let serviceType = "firework-sync"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var groupOriginPrivate: SIMD3<Float>?  // グループの中点
    private var groupToPeerMap: [String: MCPeerID] = [:]  // グループ名 -> ピアIDのマップ
    
    // MARK: - Events (Combineで購読)
    let fireworkLaunchSubject = PassthroughSubject<(FireworkShell2D, SIMD3<Float>, Date), Never>()
    
    // MARK: - Init (自動で広告とブラウズ開始)
    override init() {
        super.init()
        print("[P2P] P2PManager initialized")
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        // 広告: 自分のデバイスを「見つけてもらう」ためにブロードキャスト開始
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()  // これで他のデバイスに「このグループありますよ」と知らせる
        print("[P2P] Started advertising")
        
        // ブラウズ: 他のデバイスのグループを探す
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()  // これで近くのグループを見つける
        print("[P2P] Started browsing")
    }
    
    // MARK: - API Methods
    
    /// グループ作成 (ホストになる)
    func createGroup(name: String) {
        currentGroupName = name
        print("[P2P] Creating group: \(name)")
        // 広告のdiscoveryInfoにグループ名を追加して、他のデバイスが見つけやすいように
        advertiser.stopAdvertisingPeer()
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["groupName": name], serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
    }
    
    /// グループ参加 (ゲストになる)
    func joinGroup(name: String) {
        print("[P2P] Joining group: \(name)")
        // groupToPeerMapから該当のピアを探して招待
        if let peer = groupToPeerMap[name] {
            browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
            print("[P2P] Invited peer: \(peer.displayName)")
        } else {
            print("[P2P] Peer not found for group: \(name)")
        }
    }
    
    /// グループ離脱
    func leaveGroup() {
        print("[P2P] Leaving group")
        session.disconnect()
        connectedPeers = []
        isConnected = false
        currentGroupName = nil
        groupOriginPrivate = nil
        groupToPeerMap = [:]
        availableGroups = []
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
    }
    
    /// 花火発射データを送信 (相対座標 + タイムスタンプ)
    func sendFireworkLaunch(shell: FireworkShell2D, relativePosition: SIMD3<Float>) {
        let timestamp = Date().addingTimeInterval(0.01)  // 10ms後
        print("[P2P] Sending firework launch: position \(relativePosition), timestamp \(timestamp)")
        
        // shellをJSONエンコードしてbase64に変換
        guard let shellData = try? JSONEncoder().encode(shell) else {
            print("[P2P] Failed to encode shell")
            return
        }
        let shellBase64 = shellData.base64EncodedString()
        
        let data: [String: Any] = [
            "shell": shellBase64,
            "position": [relativePosition.x, relativePosition.y, relativePosition.z],
            "timestamp": timestamp.timeIntervalSince1970
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: data) {
            try? session.send(jsonData, toPeers: session.connectedPeers, with: .reliable)
        }
    }
    
    /// 中点設定
    func setGroupOrigin(origin: SIMD3<Float>) {
        groupOriginPrivate = origin
        print("[P2P] Set group origin: \(origin)")
    }
    
    // MARK: - Private Helpers
    // private var foundPeers: [MCPeerID] = []  // ブラウズで見つけたピア
}

// MARK: - MCSessionDelegate
extension P2PManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("[P2P] Connected to peer: \(peerID.displayName)")
                self.connectedPeers.append(peerID)
                self.isConnected = true
            case .connecting:
                print("[P2P] Connecting to peer: \(peerID.displayName)")
            case .notConnected:
                print("[P2P] Disconnected from peer: \(peerID.displayName)")
                self.connectedPeers.removeAll { $0 == peerID }
                self.isConnected = self.connectedPeers.count > 0
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        print("[P2P] Received data from: \(peerID.displayName)")
        
        // 重い処理をバックグラウンドで実行
        DispatchQueue.global(qos: .userInitiated).async {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let shellBase64 = dict["shell"] as? String,
               let shellData = Data(base64Encoded: shellBase64),
               let positionArray = dict["position"] as? [Float],
               let timestampInterval = dict["timestamp"] as? TimeInterval {
                
                let shell = try! JSONDecoder().decode(FireworkShell2D.self, from: shellData)
                let position = SIMD3<Float>(positionArray[0], positionArray[1], positionArray[2])
                let timestamp = Date(timeIntervalSince1970: timestampInterval)
                
                print("[P2P] Decoded firework: position \(position), timestamp \(timestamp)")
                
                // タイムスタンプまで待って発火
                let delay = max(0, timestamp.timeIntervalSinceNow)
                print("[P2P] Scheduling firework launch in \(delay) seconds")
                
                // メインスレッドでスケジューリング
                DispatchQueue.main.async {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        print("[P2P] Firing received firework")
                        self.fireworkLaunchSubject.send((shell, position, timestamp))
                    }
                }
            } else {
                print("[P2P] Failed to decode received data")
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser Delegate (広告関連)
extension P2PManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[P2P] Received invitation from: \(peerID.displayName)")
        // 招待を受け入れる (自動)
        invitationHandler(true, session)
    }
}

// MARK: - Browser Delegate (ブラウズ関連)
extension P2PManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("[P2P] Found peer: \(peerID.displayName), info: \(info ?? [:])")
        // foundPeers.append(peerID)
        if let groupName = info?["groupName"] {
            availableGroups.append(groupName)
            groupToPeerMap[groupName] = peerID
            print("[P2P] Added group: \(groupName) -> peer: \(peerID.displayName)")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[P2P] Lost peer: \(peerID.displayName)")
        // foundPeers.removeAll { $0 == peerID }
        // 失われたピアに対応するグループを削除
        for (groupName, peer) in groupToPeerMap {
            if peer == peerID {
                availableGroups.removeAll { $0 == groupName }
                groupToPeerMap.removeValue(forKey: groupName)
                print("[P2P] Removed group: \(groupName)")
                break
            }
        }
    }
}
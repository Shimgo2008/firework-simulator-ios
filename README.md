# Firework Simulator iOS

AR技術とMetalシェーダーを使用した花火シミュレーターiOSアプリです。複数のデバイス間でP2P接続により花火の発射を同期できます。

## 機能

- **AR花火シミュレーション**: ARKitを使用して現実世界に花火を投影
- **花火エディタ**: 花火の種類、色、軌道をカスタマイズ
- **P2P同期**: MultipeerConnectivityを使用して近くのデバイスと花火の発射を同期
- **リアルタイムレンダリング**: Metalシェーダーで高品質な花火エフェクトを実現

## 必要条件

- iOS 15.0以上
- Xcode 13.0以上
- ARKit対応デバイス

## インストール

1. このリポジトリをクローンします：
   ```sh
   git clone https://github.com/Shimgo2008/firework-simulator-ios.git
   ```

2. Xcodeでプロジェクトを開きます：
   ```sh
   open FireWorkSimulator.xcodeproj
   ```

3. シミュレーターまたは実機でビルドして実行します。

## 使用方法

1. アプリを起動するとARビューが表示されます。
2. 画面をタップして花火を発射します。
3. エディタビューで花火の設定を変更できます。
4. P2P同期を有効にして、近くのデバイスと同期します。

## アーキテクチャ

- **SwiftUI**: UI構築
- **ARKit**: AR機能
- **Metal**: GPUアクセラレーションによるレンダリング
- **MultipeerConnectivity**: P2P通信

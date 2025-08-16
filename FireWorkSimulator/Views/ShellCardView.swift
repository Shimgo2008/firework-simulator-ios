//
//  ShellCardView.swift
//  FireWorkSimulator
//
//  Created by 岩澤慎平 on 2025/08/16.
//

import SwiftUI

struct ShellCardView: View {
    let shell: FireworkShell2D
    
    private let cardWidth: CGFloat = 160
    private let previewDiameter: CGFloat = 80 // プレビュー領域の直径
    
    var body: some View {
        VStack(spacing: 8) {
            previewArea
            infoArea
        }
        .frame(width: cardWidth)
        .background(Color(.systemBackground)) // ダークモード対応
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private var previewArea: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(height: 120)

            // 星のプレビュー
            ZStack {
                Circle().fill(Color(red: 232/255, green: 165/255, blue: 71/255))
                    .frame(width: previewDiameter + 10, height: previewDiameter + 10)
                
                Circle().fill(Color.black)
                    .frame(width: previewDiameter, height: previewDiameter)
                
                // EditorViewのキャンバス半径(150)とプレビュー半径(40)の比率でスケール
                let scale = (previewDiameter / 2) / 150.0
                
                ForEach(shell.stars) { star in
                    Circle()
                        .fill(star.color)
                        // <<<--- 星ごとのサイズをスケールして反映
                        .frame(width: star.size * scale, height: star.size * scale)
                        .position(
                            x: (cardWidth / 2) + star.position.x * scale,
                            y: 60 + star.position.y * scale
                        )
                }
            }
        }
        .clipped()
    }
    
    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shell.name)
                .font(.headline)
                .lineLimit(1)
            
            HStack {
                Text("星: \(shell.stars.count)")
                Spacer()
                Text("半径: \(Int(shell.shellRadius))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

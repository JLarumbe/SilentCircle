//
//  StatusGroup.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI

public struct StatusGroup: View {
    let icon: String
    let iconColor: Color
    let title: String
    let status: String
    var background: Color = .clear
    
    public init(icon: String, iconColor: Color, title: String, status: String, background: Color = .clear) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.status = status
        self.background = background
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)
            }
            
            // Status Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(status)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(background)
        .cornerRadius(12)
    }
} 
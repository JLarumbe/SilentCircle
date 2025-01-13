import SwiftUI

struct StatusIndicator: View {
    let icon: String
    let iconColor: Color
    let status: String
    var background: Color = .clear
    
    var body: some View {
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
            Text(status)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(12)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    VStack(spacing: 8) {
        StatusIndicator(
            icon: "location.fill",
            iconColor: .purple,
            status: "Available"
        )
        
        StatusIndicator(
            icon: "checkmark.circle.fill",
            iconColor: .purple,
            status: "Active"
        )
        
        StatusIndicator(
            icon: "bell.fill",
            iconColor: .purple,
            status: "Home",
            background: Color.purple.opacity(0.1)
        )
    }
    .padding()
} 
//
//  StatusBarView.swift
//  SilentCircle
//
//  Created by Jorge Larumbe on 1/5/25.
//

import SwiftUI

public struct StatusBarView: View {
    @EnvironmentObject private var locationManager: LocationManager
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Location Status
            StatusIndicator(
                icon: locationStatusIcon,
                iconColor: locationStatusColor,
                status: locationStatusText
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Location Status: \(locationStatusText)")
            
            // Monitoring Status
            StatusIndicator(
                icon: monitoringStatusIcon,
                iconColor: monitoringStatusColor,
                status: monitoringStatusText
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Monitoring Status: \(monitoringStatusText)")
            
            if let name = activeGeofenceName {
                StatusIndicator(
                    icon: "bell.fill",
                    iconColor: .purple,
                    status: name,
                    background: Color.purple.opacity(0.1)
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Currently active Silent Circle: \(name)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
    
    // Location Status
    private var locationStatusIcon: String {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return "location.fill"
        case .noLocation, .notAuthorized:
            return "location.slash.fill"
        case .unknown:
            return "location.circle"
        }
    }
    
    private var locationStatusColor: Color {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return .purple
        case .noLocation:
            return .orange
        case .notAuthorized:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var locationStatusText: String {
        switch locationManager.monitoringStatus {
        case .ready, .noGeofences:
            return "Available"
        case .noLocation:
            return "Disabled"
        case .notAuthorized:
            return "Not Authorized"
        case .unknown:
            return "Checking..."
        }
    }
    
    // Monitoring Status
    private var monitoringStatusIcon: String {
        switch locationManager.monitoringStatus {
        case .ready:
            return "checkmark.circle.fill"
        case .noGeofences:
            return "mappin.slash.circle.fill"
        case .noLocation:
            return "exclamationmark.triangle.fill"
        case .notAuthorized:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "ellipsis.circle.fill"
        }
    }
    
    private var monitoringStatusColor: Color {
        switch locationManager.monitoringStatus {
        case .ready:
            return .purple
        case .noGeofences:
            return .purple
        case .noLocation:
            return .orange
        case .notAuthorized:
            return .red
        case .unknown:
            return .gray
        }
    }
    
    private var monitoringStatusText: String {
        switch locationManager.monitoringStatus {
        case .ready:
            return "Active"
        case .noGeofences:
            return "No Active Circles"
        case .noLocation:
            return "Location Required"
        case .notAuthorized:
            return "Permission Required"
        case .unknown:
            return "Checking..."
        }
    }
    
    // Add this to observe currentGeofence changes
    private var activeGeofenceName: String? {
        locationManager.currentGeofence?.name
    }
} 
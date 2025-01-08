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
        VStack(spacing: 12) {
            // Location Status Group
            StatusGroup(
                icon: locationStatusIcon,
                iconColor: locationStatusColor,
                title: "Location",
                status: locationStatusText,
                background: .clear
            )
            
            // Monitoring Status Group
            StatusGroup(
                icon: monitoringStatusIcon,
                iconColor: monitoringStatusColor,
                title: "Monitoring",
                status: monitoringStatusText,
                background: .clear
            )
            
            // Active Circle Status - Only show when inside a geofence
            if let name = activeGeofenceName {
                StatusGroup(
                    icon: "checkmark.shield.fill",
                    iconColor: .green,
                    title: "Active Circle",
                    status: name,
                    background: Color.green.opacity(0.1)
                )
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
            return .green
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
            return .green
        case .noGeofences:
            return .blue
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
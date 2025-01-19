import CoreLocation

extension CLLocationDistance {
    func formatted(unit: DistanceUnit) -> String {
        let meters = self
        switch unit {
        case .kilometers:
            if meters < 1000 {
                return "\(Int(meters))m"
            } else {
                return String(format: "%.1fkm", meters / 1000)
            }
        case .miles:
            let miles = meters / 1609.34
            if miles < 0.1 {
                return "\(Int(meters))m"
            } else {
                return String(format: "%.1fmi", miles)
            }
        }
    }
} 
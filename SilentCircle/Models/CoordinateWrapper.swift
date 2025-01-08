import CoreLocation

struct CoordinateWrapper: Equatable {
    let coordinate: CLLocationCoordinate2D
    
    init(_ coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
    
    static func == (lhs: CoordinateWrapper, rhs: CoordinateWrapper) -> Bool {
        return abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < .ulpOfOne &&
               abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < .ulpOfOne
    }
    
    init(latitude: Double, longitude: Double) {
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
} 
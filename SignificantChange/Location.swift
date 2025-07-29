import CoreLocation
import Foundation
import SharingGRDB

@Table struct Location: Hashable, Identifiable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double?
    var timestamp: Date
    var horizontalAccuracy: Double?
    var verticalAccuracy: Double?
    var course: Double?
    var speed: Double?
    var isFromColdLaunch: Bool

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date = Date(),
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        course: Double? = nil,
        speed: Double? = nil,
        isFromColdLaunch: Bool = false
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.course = course
        self.speed = speed
        self.isFromColdLaunch = isFromColdLaunch
    }
}

extension Location {
    init(from clLocation: CLLocation, isFromColdLaunch: Bool = false) {
        self.init(
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            altitude: clLocation.altitude,
            timestamp: clLocation.timestamp,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            verticalAccuracy: clLocation.verticalAccuracy,
            course: clLocation.course >= 0 ? clLocation.course : nil,
            speed: clLocation.speed >= 0 ? clLocation.speed : nil,
            isFromColdLaunch: isFromColdLaunch
        )
    }
}

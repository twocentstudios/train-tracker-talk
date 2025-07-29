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
    var sessionID: Session.ID

    init(
        id: UUID,
        latitude: Double,
        longitude: Double,
        altitude: Double? = nil,
        timestamp: Date,
        horizontalAccuracy: Double? = nil,
        verticalAccuracy: Double? = nil,
        course: Double? = nil,
        speed: Double? = nil,
        sessionID: Session.ID
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
        self.sessionID = sessionID
    }
}

extension Location {
    init(from clLocation: CLLocation, id: UUID, sessionID: Session.ID) {
        self.init(
            id: id,
            latitude: clLocation.coordinate.latitude,
            longitude: clLocation.coordinate.longitude,
            altitude: clLocation.altitude,
            timestamp: clLocation.timestamp,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            verticalAccuracy: clLocation.verticalAccuracy,
            course: clLocation.course >= 0 ? clLocation.course : nil,
            speed: clLocation.speed >= 0 ? clLocation.speed : nil,
            sessionID: sessionID
        )
    }
}

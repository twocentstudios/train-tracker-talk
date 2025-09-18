import MapKit
import SharingGRDB
import SwiftUI

struct ClosestPoint: Identifiable {
    var id: Railway.ID { railway }
    let railway: Railway.ID
    let coordinate: CLLocationCoordinate2D
}

struct Talk01View: View {
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]
    @State var stationCoordinates: [Railway.ID: [CLLocationCoordinate2D]] = [:]

    let closestPoints: [ClosestPoint] = [
        .init(railway: "Tokyu.TokyuShinYokohama", coordinate: .init(latitude: 35.5339235, longitude: 139.6353437)),
        .init(railway: "Tokyu.Toyoko", coordinate: .init(latitude: 35.5349294, longitude: 139.6338753)),
        .init(railway: "Tokyu.Meguro", coordinate: .init(latitude: 35.5523825, longitude: 139.646616)),
        .init(railway: "YokohamaMunicipal.Green", coordinate: .init(latitude: 35.548391, longitude: 139.62981)),
    ]

    let location = CLLocationCoordinate2D(latitude: 35.53486545405764, longitude: 139.6337659049049)

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(railways.values)) { railway in
                    if let coordinates = coordinates[railway.id] {
                        MapPolyline(coordinates: coordinates.map(\.coordinate), contourStyle: .geodesic)
                            .stroke(Color(hexString: railway.color).mix(with: .black, by: 0.1), style: .init(lineWidth: 1, lineCap: .round, lineJoin: .bevel, miterLimit: 1, dash: [2, 2], dashPhase: 1))
                    }
                }
                ForEach(stationCoordinates.values.flatMap(\.self), id: \.latitude) { coordinate in
                    MapCircle(center: coordinate, radius: 25)
                        .stroke(.black, lineWidth: 3)
                        .foregroundStyle(Color.white)
                }
                ForEach(closestPoints) { point in
                    if let color = railways[point.railway]?.color {
                        MapCircle(center: point.coordinate, radius: 05)
                            .foregroundStyle(Color(hexString: color))
                    }
                }
                MapCircle(center: location, radius: 10)
                    .foregroundStyle(Color(white: 0.25))
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .including([.publicTransport]), showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["Tokyu.Toyoko", "Tokyu.TokyuShinYokohama", "Tokyu.Meguro", "YokohamaMunicipal.Green"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
            stationCoordinates[railway.id] =
                try! await database.read { db in
                    try Station
                        .where {
                            $0.railway.eq(railway.id)
                        }
                        .order(by: \.order)
                        .fetchAll(db)
                        .map { station in
                            print(station.id, station.coordinate)
                            return CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            )
                        }
                }
        }
    }
}

struct Talk02View: View {
    let document: SessionDatabase
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]
    @State var stationCoordinates: [Railway.ID: [CLLocationCoordinate2D]] = [:]

    let closestPoints: [ClosestPoint] = [
        .init(railway: "Tokyu.Toyoko", coordinate: .init(latitude: 35.5349294, longitude: 139.6338753)),
        .init(railway: "Tokyu.Meguro", coordinate: .init(latitude: 35.5523825, longitude: 139.646616)),
    ]

    let location = CLLocationCoordinate2D(latitude: 35.5597781509179, longitude: 139.651592940558)
    @State var locations: [Location] = []

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(railways.values)) { railway in
                    if let coordinates = coordinates[railway.id] {
                        MapPolyline(coordinates: coordinates.map(\.coordinate), contourStyle: .geodesic)
                            .stroke(Color(hexString: railway.color).mix(with: .black, by: 0.1), style: .init(lineWidth: 5, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [1, 9], dashPhase: railway.id == "Tokyu.Toyoko" ? 4.0 : 0.0))
                    }
                }
                if locations.count > 1 {
                    MapPolyline(coordinates: locations.map(\.coordinate), contourStyle: .geodesic)
                        .stroke(Color(white: 0.25), style: .init(lineWidth: 8, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [5, 10], dashPhase: 2.0))
                }
//                ForEach(stationCoordinates.values.flatMap(\.self), id: \.latitude) { coordinate in
//                    MapCircle(center: coordinate, radius: 25)
//                        .stroke(.black, lineWidth: 3)
//                        .foregroundStyle(Color.white)
//                }
//                ForEach(closestPoints) { point in
//                    if let color = railways[point.railway]?.color {
//                        MapCircle(center: point.coordinate, radius: 05)
//                            .foregroundStyle(Color(hexString: color))
//                    }
//                }
//                MapCircle(center: location, radius: 15)
//                    .foregroundStyle(Color(white: 0.25))
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .including([.publicTransport]), showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        let userDatabase = try! openAppDatabase(path: document.fileURL.path)
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["Tokyu.Toyoko", "Tokyu.Meguro"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
            stationCoordinates[railway.id] =
                try! await database.read { db in
                    try Station
                        .where {
                            $0.railway.eq(railway.id)
                        }
                        .order(by: \.order)
                        .fetchAll(db)
                        .map { station in
                            print(station.id, station.coordinate)
                            return CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            )
                        }
                }
            locations =
                try! await userDatabase.read { db in
                    try Location
                        .where {
                            $0.sessionID.eq(Session.ID(uuidString: "4bdda56f-04bc-4f61-b7f3-9cde8fcdeb96")!)
                        }
                        .order(by: \.timestamp)
                        .fetchAll(db)
                }
        }
    }
}

struct Talk03View: View {
    let document: SessionDatabase
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]
    @State var stationCoordinates: [Railway.ID: [CLLocationCoordinate2D]] = [:]

    let closestPoints: [ClosestPoint] = []

    let location = CLLocationCoordinate2D(latitude: 35.5536284897121, longitude: 139.71239103419)
    @State var locations: [Location] = []

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(railways.values)) { railway in
                    if let coordinates = coordinates[railway.id] {
                        MapPolyline(coordinates: coordinates.map(\.coordinate), contourStyle: .geodesic)
                            .stroke(Color(hexString: railway.color).mix(with: .black, by: 0.1), style: .init(lineWidth: 5, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [1, 9], dashPhase: railway.id == "JR-East.Tokaido" ? 4.0 : 0.0))
                            .mapOverlayLevel(level: .aboveLabels)
                    }
                }
//                if locations.count > 1 {
//                    MapPolyline(coordinates: locations.map(\.coordinate), contourStyle: .geodesic)
//                        .stroke(Color(white: 0.25), style: .init(lineWidth: 8, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [5, 10], dashPhase: 2.0))
//                }
                ForEach(stationCoordinates.keys.sorted(), id: \.self) { railwayID in
                    let values = stationCoordinates[railwayID]!
                    let railway = railways[railwayID]!
                    ForEach(values, id: \.latitude) { coordinate in
                        MapCircle(center: coordinate, radius: 225)
                            .stroke(.black, lineWidth: 3)
                            .foregroundStyle(Color(hexString: railway.color))
                            .mapOverlayLevel(level: .aboveLabels)
                    }
                }
                //                ForEach(closestPoints) { point in
                //                    if let color = railways[point.railway]?.color {
                //                        MapCircle(center: point.coordinate, radius: 05)
                //                            .foregroundStyle(Color(hexString: color))
                //                    }
                //                }
//                MapCircle(center: location, radius: 25)
//                    .foregroundStyle(Color(white: 0.25))
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        let userDatabase = try! openAppDatabase(path: document.fileURL.path)
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["JR-East.KeihinTohokuNegishi", "JR-East.Tokaido"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
            stationCoordinates[railway.id] =
                try! await database.read { db in
                    try Station
                        .where {
                            $0.railway.eq(railway.id)
                        }
                        .order(by: \.order)
                        .fetchAll(db)
                        .map { station in
                            print(station.id, station.coordinate)
                            return CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            )
                        }
                }
            locations =
                try! await userDatabase.read { db in
                    try Location
                        .where {
                            $0.sessionID.eq(Session.ID(uuidString: "f152c05e-45c3-4f6b-94b9-0eb9db398c1b")!)
                        }
                        .order(by: \.timestamp)
                        .fetchAll(db)
                }
        }
    }
}

struct Talk04View: View {
    let document: SessionDatabase
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]
    @State var stationCoordinates: [Railway.ID: [CLLocationCoordinate2D]] = [:]

    let closestPoints: [ClosestPoint] = []

    let location = CLLocationCoordinate2D(latitude: 35.53486545405764, longitude: 139.6337659049049)
    let locationCourse = CLLocationDegrees(359.433)
    @State var locations: [Location] = []

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
//                ForEach(Array(railways.values)) { railway in
//                    if let coordinates = coordinates[railway.id] {
//                        MapPolyline(coordinates: coordinates.map(\.coordinate), contourStyle: .geodesic)
//                            .stroke(Color(hexString: railway.color).mix(with: .black, by: 0.1), style: .init(lineWidth: 3, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [1, 4], dashPhase: 0.0))
//                            .mapOverlayLevel(level: .aboveLabels)
//                    }
//                }
                //                if locations.count > 1 {
                //                    MapPolyline(coordinates: locations.map(\.coordinate), contourStyle: .geodesic)
                //                        .stroke(Color(white: 0.25), style: .init(lineWidth: 8, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [5, 10], dashPhase: 2.0))
                //                }
                ForEach(stationCoordinates.keys.sorted(), id: \.self) { railwayID in
                    let values = stationCoordinates[railwayID]!
                    let railway = railways[railwayID]!
                    ForEach(values, id: \.latitude) { coordinate in
                        MapCircle(center: coordinate, radius: 25)
                            .stroke(.black, lineWidth: 3)
//                            .foregroundStyle(.white)
                            .foregroundStyle(Color(hexString: railway.color))
                            .mapOverlayLevel(level: .aboveLabels)
                    }
                }
                //                ForEach(closestPoints) { point in
                //                    if let color = railways[point.railway]?.color {
                //                        MapCircle(center: point.coordinate, radius: 05)
                //                            .foregroundStyle(Color(hexString: color))
                //                    }
                //                }
//                Annotation("", coordinate: location) {
//                    Image(systemName: "arrow.up")
//                        .resizable()
//                        .aspectRatio(contentMode: .fit)
//                        .rotationEffect(.degrees(locationCourse))
//                        .foregroundStyle(Color(white: 0.25))
//                        .frame(width: 50)
//                }
                MapCircle(center: location, radius: 25)
                    .foregroundStyle(Color(white: 0.25))
                    .mapOverlayLevel(level: .aboveLabels)
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        let userDatabase = try! openAppDatabase(path: document.fileURL.path)
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["Tokyu.Toyoko"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
            stationCoordinates[railway.id] =
                try! await database.read { db in
                    try Station
                        .where {
                            $0.railway.eq(railway.id)
                        }
                        .order(by: \.order)
                        .fetchAll(db)
                        .map { station in
                            print(station.id, station.coordinate)
                            return CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            )
                        }
                }
            locations =
                try! await userDatabase.read { db in
                    try Location
                        .where {
                            $0.sessionID.eq(Session.ID(uuidString: "f152c05e-45c3-4f6b-94b9-0eb9db398c1b")!)
                        }
                        .order(by: \.timestamp)
                        .fetchAll(db)
                }
        }
    }
}

struct Talk05View: View {
    let document: SessionDatabase
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]
    @State var stationCoordinates: [Railway.ID: [CLLocationCoordinate2D]] = [:]

    let closestPoints: [ClosestPoint] = []

    let location = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    let locationCourse = CLLocationDegrees(0)
    @State var locations: [Location] = []

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(railways.values)) { railway in
                    if let coordinates = coordinates[railway.id] {
                        MapPolyline(coordinates: coordinates.map(\.coordinate), contourStyle: .geodesic)
                            .stroke(Color(hexString: railway.color).mix(with: .black, by: 0.1), style: .init(lineWidth: 3, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [1, 4], dashPhase: 0.0))
                            .mapOverlayLevel(level: .aboveLabels)
                    }
                }
                //                if locations.count > 1 {
                //                    MapPolyline(coordinates: locations.map(\.coordinate), contourStyle: .geodesic)
                //                        .stroke(Color(white: 0.25), style: .init(lineWidth: 8, lineCap: .round, lineJoin: .miter, miterLimit: 0, dash: [5, 10], dashPhase: 2.0))
                //                }
                ForEach(stationCoordinates.keys.sorted(), id: \.self) { railwayID in
                    let values = stationCoordinates[railwayID]!
                    let railway = railways[railwayID]!
                    ForEach(values, id: \.latitude) { coordinate in
                        MapCircle(center: coordinate, radius: 10)
                            .foregroundStyle(.white)
                            .mapOverlayLevel(level: .aboveLabels)
//                        MapCircle(center: coordinate, radius: 200)
//                            .stroke(.black, lineWidth: 3)
//                            .foregroundStyle(.orange.opacity(0.5))
//                            .foregroundStyle(Color(hexString: railway.color))
//                            .mapOverlayLevel(level: .aboveLabels)
//                        MapCircle(center: coordinate, radius: 500)
//                            .foregroundStyle(.blue.opacity(0.2))
//                            .mapOverlayLevel(level: .aboveLabels)
                    }
                }
                //                ForEach(closestPoints) { point in
                //                    if let color = railways[point.railway]?.color {
                //                        MapCircle(center: point.coordinate, radius: 05)
                //                            .foregroundStyle(Color(hexString: color))
                //                    }
                //                }
                //                Annotation("", coordinate: location) {
                //                    Image(systemName: "arrow.up")
                //                        .resizable()
                //                        .aspectRatio(contentMode: .fit)
                //                        .rotationEffect(.degrees(locationCourse))
                //                        .foregroundStyle(Color(white: 0.25))
                //                        .frame(width: 50)
                //                }
//                MapCircle(center: location, radius: 25)
//                    .foregroundStyle(Color(white: 0.25))
//                    .mapOverlayLevel(level: .aboveLabels)
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        let userDatabase = try! openAppDatabase(path: document.fileURL.path)
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["JR-East.KeihinTohokuNegishi"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
            stationCoordinates[railway.id] =
                try! await database.read { db in
                    try Station
                        .where {
                            $0.railway.eq(railway.id)
                        }
                        .order(by: \.order)
                        .fetchAll(db)
                        .map { station in
                            print(station.id, station.coordinate)
                            return CLLocationCoordinate2D(
                                latitude: station.coordinate.latitude,
                                longitude: station.coordinate.longitude
                            )
                        }
                }
            locations =
                try! await userDatabase.read { db in
                    try Location
                        .where {
                            $0.sessionID.eq(Session.ID(uuidString: "f152c05e-45c3-4f6b-94b9-0eb9db398c1b")!)
                        }
                        .order(by: \.timestamp)
                        .fetchAll(db)
                }
        }
    }
}

struct Talk06View: View {
    let document: SessionDatabase
    @State private var railwayDatabase: (any DatabaseReader)?

    @State var railways: [Railway.ID: Railway] = [:]
    @State var coordinates: [Railway.ID: [Coordinate]] = [:]

    @State private var cameraPosition = MapCameraPosition.automatic

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                ForEach(Array(railways.values)) { railway in
                    if let coordinates = coordinates[railway.id] {
                        ForEach(coordinates) { coordinate in
                            MapCircle(center: coordinate.coordinate, radius: 10)
                                .foregroundStyle(Color(hexString: railway.color))
                                .mapOverlayLevel(level: .aboveLabels)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .automatic, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        }
        .task {
            await openDatabase()
        }
    }

    private func openDatabase() async {
        let database = try! openRailwayDatabase()
        railwayDatabase = database

        let railwaysToFetch: [Railway.ID] = ["Tokyu.Toyoko"]

        railways = try! await database.read { db in
            let array = try Railway
                .where { $0.id.in(railwaysToFetch) }
                .fetchAll(db)
            let dictionary = array.reduce(into: [:]) { acc, railway in
                acc[railway.id] = railway
            }
            return dictionary
        }
        for railway in railways.values {
            coordinates[railway.id] = try! await database.read { db in
                try #sql(
                    """
                    SELECT c.*
                    FROM segment AS s
                    JOIN segmentCoordinate AS sc ON sc.segment  = s.id
                    JOIN coordinate        AS c  ON c.id        = sc.coordinate
                    WHERE s.railway = \(bind: railway.id.rawValue)
                    ORDER BY s."order", sc."order"
                    """,
                    as: Coordinate.self
                )
                .fetchAll(db)
            }
        }
    }
}

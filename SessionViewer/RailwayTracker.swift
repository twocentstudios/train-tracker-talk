import SharingGRDB

struct RailwayTrackerResult {
    let location: Location
    let value: Int
}

actor RailwayTracker {
    private let railwayDatabase: (any DatabaseReader)?

    private var count: Int = 0

    init(railwayDatabase: (any DatabaseReader)?) {
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) async -> RailwayTrackerResult {
        try? await Task.sleep(for: .seconds(0.1))
        count += 1
        return RailwayTrackerResult(location: input, value: count)
    }

    func reset() {
        count = 0
    }
}

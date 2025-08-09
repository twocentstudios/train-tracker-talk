import SharingGRDB

struct RailwayTrackerResult {
    let value: Int
}

actor RailwayTracker {
    private let railwayDatabase: (any DatabaseReader)?
    
    private var count: Int = 0

    init(railwayDatabase: (any DatabaseReader)?) {
        print("ASDF RailwayTracker init")
        self.railwayDatabase = railwayDatabase
    }

    func process(_ input: Location) async -> RailwayTrackerResult {
        try? await Task.sleep(for: .seconds(0.5))
        count += 1
        return RailwayTrackerResult(value: count)
    }
    
    deinit {
        print("ASDF RailwayTracker deinit")
    }

    func reset() {
        count = 0
    }
}

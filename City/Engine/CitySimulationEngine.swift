import Foundation

struct SimulationResult: Sendable {
    let treasury: Double
    let population: Int
    let day: Int
    let commercialDemand: Int
    let residentialDemand: Int
    let upgrades: [(x: Int, y: Int)]
    let taxCollected: Double
}

// Actor isolates heavy simulation math off the main thread.
actor CitySimulationEngine {
    private(set) var treasury: Double = 10_000
    private(set) var population: Int = 0
    private(set) var day: Int = 0
    private(set) var commercialDemand: Int = 0
    private(set) var residentialDemand: Int = 0

    /// Returns false if insufficient funds.
    func spend(_ amount: Double) -> Bool {
        guard treasury >= amount else { return false }
        treasury -= amount
        return true }

    /// Takes a snapshot of cells so the grid never crosses the actor boundary.
    func tick(cells: [[CityCell]]) -> SimulationResult {
        day += 1
        var taxCollected: Double = 0
        var upgrades: [(x: Int, y: Int)] = []

        let flat = cells.flatMap { $0 }
        let residential = flat.filter { $0.zone == .residential }
        let commercialCnt = flat.filter { $0.zone == .commercial }.count
        let industrialCnt = flat.filter { $0.zone == .industrial }.count

        // Demand loop
        if residential.count > commercialCnt {
            commercialDemand = min(commercialDemand + 1, 100)
        } else {
            commercialDemand = max(commercialDemand - 1, 0)
        }
        let jobs = commercialCnt * 2 + industrialCnt * 3
        if jobs > population {
            residentialDemand = min(residentialDemand + 1, 100)
        } else {
            residentialDemand = max(residentialDemand - 1, 0)
        }

        // Tax engine: fires every 30 game days
        if day % 30 == 0 {
            for cell in flat where cell.zone != .empty && cell.zone != .road {
                taxCollected += Double(cell.level + 1) * 10
            }
            treasury += taxCollected
        }

        // Upgrade mechanic: residential with road neighbours may level up
        for cell in residential where cell.level < 3 {
            let hasRoad = [
                (cell.x - 1, cell.y), (cell.x + 1, cell.y),
                (cell.x, cell.y - 1), (cell.x, cell.y + 1)
            ].contains { nx, ny in
                flat.first { $0.x == nx && $0.y == ny }?.zone == .road
            }
            if hasRoad, Double.random(in: 0...1) < 0.02 {
                upgrades.append((cell.x, cell.y))
            }
        }

        // Recalculate population
        population = residential.reduce(0) { $0 + ($1.level + 1) * 4 }

        return SimulationResult(
            treasury: treasury,
            population: population,
            day: day,
            commercialDemand: commercialDemand,
            residentialDemand: residentialDemand,
            upgrades: upgrades,
            taxCollected: taxCollected
        )
    }
}

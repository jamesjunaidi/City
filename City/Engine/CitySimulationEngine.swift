import Foundation
import Observation

// @Observable so it can be stored safely in @State.
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor means all methods already
// run on the main thread — a separate actor boundary is unnecessary and
// causes ARC corruption when SwiftUI copies the view struct across renders.
@Observable
final class CitySimulationEngine {
    private(set) var treasury: Double = 10_000
    private(set) var population: Int = 0
    private(set) var day: Int = 0
    private(set) var commercialDemand: Int = 0
    private(set) var residentialDemand: Int = 0

    /// Returns false and leaves treasury unchanged if funds are insufficient.
    @discardableResult
    func spend(_ amount: Double) -> Bool {
        guard treasury >= amount else { return false }
        treasury -= amount
        return true
    }

    /// Advances one game day and returns the result.
    func tick(grid: CityGrid) -> SimulationResult {
        day += 1
        var taxCollected: Double = 0
        var upgrades: [(x: Int, y: Int)] = []

        let flat = grid.cells.flatMap { $0 }
        let residential  = flat.filter { $0.zone == .residential }
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

        // Upgrade mechanic: residential cells adjacent to a road may level up
        for cell in residential where cell.level < 3 {
            if grid.hasRoadAccess(at: cell.x, y: cell.y),
               Double.random(in: 0...1) < 0.02 {
                upgrades.append((cell.x, cell.y))
            }
        }

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

struct SimulationResult {
    let treasury: Double
    let population: Int
    let day: Int
    let commercialDemand: Int
    let residentialDemand: Int
    let upgrades: [(x: Int, y: Int)]
    let taxCollected: Double
}

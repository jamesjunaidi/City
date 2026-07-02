import Foundation
import Observation

@Observable
@MainActor
final class CitySimulationEngine {
    private(set) var playerFunds: Int = 20_000
    private(set) var population: Int = 0
    private(set) var taxRate: Float = 0.12
    private(set) var demandResidential: Float = 0
    private(set) var demandCommercial: Float = 0
    private(set) var demandOffice: Float = 0

    private let baseTax: [ZoneType: Int] = [
        .residential: 2,
        .commercial: 4,
        .office: 5
    ]

    @discardableResult
    func spend(_ amount: Double) -> Bool {
        let intAmount = Int(amount)
        guard playerFunds >= intAmount else { return false }
        playerFunds -= intAmount
        return true
    }

    func tick(grid: CityGrid) -> SimulationResult {
        // System A: Infrastructure Dependency Scan
        grid.scanRoadAccess()

        var upgrades: [(x: Int, y: Int, delta: Int)] = []

        // System B: Growth Engine
        for x in 0..<CityGrid.size {
            for y in 0..<CityGrid.size {
                let cell = grid.cells[x][y]
                guard cell.hasRoadAccess else { continue }

                let demand: Float
                switch cell.zone {
                case .residential: demand = demandResidential
                case .commercial:  demand = demandCommercial
                case .office:      demand = demandOffice
                default:           continue
                }

                if demand > 10, cell.level < 5 {
                    grid.adjustLevel(at: x, y: y, delta: 1)
                    upgrades.append((x, y, 1))
                } else if demand < -20, cell.level > 0 {
                    grid.adjustLevel(at: x, y: y, delta: -1)
                    upgrades.append((x, y, -1))
                }
            }
        }

        // System C: Financial & Macro Balance
        let roadCount = grid.cells.lazy.flatMap { $0 }.filter { $0.zone == .road }.count
        let roadUpkeep = roadCount * 1

        var totalTax: Int = 0
        for x in 0..<CityGrid.size {
            for y in 0..<CityGrid.size {
                let cell = grid.cells[x][y]
                guard cell.zone != .empty, cell.zone != .road else { continue }
                guard let base = baseTax[cell.zone] else { continue }
                let taxFactor = 1.0 - (Double(taxRate) - 0.12)
                let tileTax = Int(Double(base) * Double(cell.level) * taxFactor)
                totalTax += tileTax
            }
        }

        playerFunds += totalTax - roadUpkeep

        // Recalculate RCI metrics
        var totalPopulation: Int = 0
        var totalJobs: Int = 0

        for row in grid.cells {
            for cell in row {
                switch cell.zone {
                case .residential:
                    totalPopulation += cell.level * 10
                case .commercial:
                    totalJobs += cell.level * 5
                case .office:
                    totalJobs += cell.level * 8
                default:
                    break
                }
            }
        }

        population = totalPopulation

        let taxImpact: Float = (taxRate - 0.12) * 15.0

        demandResidential = max(-100, min(100, Float(totalJobs - totalPopulation) - taxImpact))
        demandCommercial = max(-100, min(100, Float(totalPopulation - totalJobs) - taxImpact))
        demandOffice = max(-100, min(100, Float(totalPopulation) * 0.2 - Float(totalJobs) - taxImpact))

        return SimulationResult(
            playerFunds: playerFunds,
            population: population,
            demandResidential: demandResidential,
            demandCommercial: demandCommercial,
            demandOffice: demandOffice,
            upgrades: upgrades
        )
    }
}

struct SimulationResult {
    let playerFunds: Int
    let population: Int
    let demandResidential: Float
    let demandCommercial: Float
    let demandOffice: Float
    let upgrades: [(x: Int, y: Int, delta: Int)]
}

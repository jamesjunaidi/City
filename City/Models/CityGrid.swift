import Foundation
import Observation
import simd

@Observable
final class CityGrid {
    static let size = 50
    static let cellSize: Float = 1.0

    var cells: [[CityCell]]

    init() {
        cells = (0..<Self.size).map { x in
            (0..<Self.size).map { y in
                CityCell(x: x, y: y, zone: .empty)
            }
        }
    }

    func cell(at x: Int, y: Int) -> CityCell? {
        guard x >= 0, x < Self.size, y >= 0, y < Self.size else { return nil }
        return cells[x][y]
    }

    func setZone(_ zone: ZoneType, at x: Int, y: Int) {
        guard x >= 0, x < Self.size, y >= 0, y < Self.size else { return }
        cells[x][y].zone = zone
    }

    func upgradeCell(at x: Int, y: Int) {
        guard x >= 0, x < Self.size, y >= 0, y < Self.size else { return }
        cells[x][y].level += 1
    }

    /// Grid (0,0) → world (-24.5, 0, -24.5). Center of grid is at origin.
    func worldPosition(for x: Int, y: Int) -> SIMD3<Float> {
        let offset = Float(Self.size) / 2.0 * Self.cellSize
        return SIMD3<Float>(
            Float(x) * Self.cellSize - offset + Self.cellSize / 2,
            0,
            Float(y) * Self.cellSize - offset + Self.cellSize / 2
        )
    }

    /// Converts a RealityKit world-space XZ position back to grid integer coordinates.
    func gridCoordinate(from worldPos: SIMD3<Float>) -> (x: Int, y: Int)? {
        let offset = Float(Self.size) / 2.0 * Self.cellSize
        let gx = Int((worldPos.x + offset) / Self.cellSize)
        let gy = Int((worldPos.z + offset) / Self.cellSize)
        guard gx >= 0, gx < Self.size, gy >= 0, gy < Self.size else { return nil }
        return (gx, gy)
    }

    func hasRoadAccess(at x: Int, y: Int) -> Bool {
        [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { nx, ny in
            cell(at: nx, y: ny)?.zone == .road
        }
    }

    var residentialCount: Int { cells.flatMap { $0 }.filter { $0.zone == .residential }.count }
    var commercialCount:  Int { cells.flatMap { $0 }.filter { $0.zone == .commercial  }.count }
    var industrialCount:  Int { cells.flatMap { $0 }.filter { $0.zone == .industrial  }.count }
}

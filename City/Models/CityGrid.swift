import Foundation
import Observation
import simd

@Observable
final class CityGrid {
    static let size = 50
    static let cellSize: Float = 1.0

    private(set) var cells: [[CityCell]]

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
        var updated = cells[x][y]
        updated.zone = zone
        cells[x][y] = updated
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

    func roadMask(at x: Int, y: Int) -> Int {
        var mask = 0
        if cell(at: x, y: y - 1)?.zone == .road { mask |= 1 }
        if cell(at: x, y: y + 1)?.zone == .road { mask |= 2 }
        if cell(at: x - 1, y: y)?.zone == .road { mask |= 4 }
        if cell(at: x + 1, y: y)?.zone == .road { mask |= 8 }
        return mask
    }

    func scanRoadAccess() {
        for x in 0..<Self.size {
            for y in 0..<Self.size {
                let cell = cells[x][y]
                guard cell.zone != .empty, cell.zone != .road else { continue }
                var updated = cell
                updated.hasRoadAccess = hasRoadAccess(at: x, y: y)
                cells[x][y] = updated
            }
        }
    }

    func adjustLevel(at x: Int, y: Int, delta: Int) {
        guard x >= 0, x < Self.size, y >= 0, y < Self.size else { return }
        var updated = cells[x][y]
        updated.level = max(0, min(5, updated.level + delta))
        cells[x][y] = updated
    }

    var residentialCount: Int {
        cells.lazy.flatMap { $0 }.filter { $0.zone == .residential }.count
    }
    var commercialCount: Int {
        cells.lazy.flatMap { $0 }.filter { $0.zone == .commercial }.count
    }
    var officeCount: Int {
        cells.lazy.flatMap { $0 }.filter { $0.zone == .office }.count
    }
}

import Foundation

enum SpriteLayer: Int {
    case ground = 0
    case road
    case lot
    case building
    case tree
}

enum SpriteCatalog {

    static func grassTile(x: Int, y: Int) -> String {
        let variants = ["cityTiles_000", "cityTiles_001", "cityTiles_002",
                        "cityTiles_003", "cityTiles_004", "cityTiles_005",
                        "cityTiles_006", "cityTiles_007"]
        let idx = (x * 7 + y * 13) % variants.count
        return variants[idx]
    }

    static func buildingTile(zone: ZoneType, level: Int) -> String {
        let mapping: [(Int, Int)] = residentialMap +
                                     commercialMap +
                                     officeMap
        for (minLv, spriteIdx) in mapping {
            if level >= minLv {
                return "buildingTiles_\(String(format: "%03d", spriteIdx))"
            }
        }
        return buildingFallback(zone: zone)
    }

    static func roadTile(bitmask: Int) -> String {
        let north = bitmask & 1 != 0
        let south = bitmask & 2 != 0
        let west  = bitmask & 4 != 0
        let east  = bitmask & 8 != 0

        let count = [north, south, west, east].filter { $0 }.count

        switch count {
        case 0:  return "road"
        case 1:
            if north { return "endN" }
            if south { return "endS" }
            if east  { return "endE" }
            if west  { return "endW" }
        case 2:
            if north && south { return "roadNS" }
            if east  && west  { return "roadEW" }
            if north && east  { return "roadNE" }
            if north && west  { return "roadNW" }
            if south && east  { return "roadES" }
            if south && west  { return "roadSW" }
        case 3:
            if !north { return "crossroadESW" }
            if !south { return "crossroadNEW" }
            if !east  { return "crossroadNSW" }
            if !west  { return "crossroadNES" }
        case 4:  return "crossroad"
        default: break
        }
        return "road"
    }

    static func treeSprite(x: Int, y: Int) -> String {
        let trees = ["treeShort", "coniferShort", "treeAltShort", "coniferAltShort",
                     "treeTall", "coniferTall", "treeAltTall", "coniferAltTall"]
        let idx = (x * 3 + y * 7) % trees.count
        return trees[idx]
    }

    static func lotSprite() -> String {
        "buildingTiles_000"
    }
}

// MARK: – Mapping tables
// Building sprite indices chosen based on typical Kenney pack layout:
//   smaller indices → smaller/denser buildings → lower levels
// The mapping is approximate; adjust numbers after inspecting sprites.
// Format: (minLevel, spriteIndex) — first match wins (highest minLevel matched first).

private let residentialMap: [(Int, Int)] = [
    (5, 1),   // Level 5: large building
    (4, 2),
    (3, 3),
    (2, 23),
    (1, 24),
]
private let commercialMap: [(Int, Int)] = [
    (5, 4),
    (4, 9),
    (3, 10),
    (2, 11),
    (1, 12),
]
private let officeMap: [(Int, Int)] = [
    (5, 25),
    (4, 26),
    (3, 27),
    (2, 29),
    (1, 30),
]

private func buildingFallback(zone: ZoneType) -> String {
    switch zone {
    case .residential: return "buildingTiles_024"
    case .commercial:  return "buildingTiles_012"
    case .office:      return "buildingTiles_030"
    default:           return "buildingTiles_000"
    }
}

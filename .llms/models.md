# Data Models

## ZoneType (`Models/ZoneType.swift`)
```swift
enum ZoneType: Codable, Equatable, Hashable, CaseIterable, Sendable {
    case empty, road, residential, commercial, office, bulldoze
}
```
- `displayName`: String — user-facing name
- `icon`: String — SF Symbol name
- `color`: Color — zone highlight color
- `buildCost`: Double — only road costs (20), others free

## CityCell (`Models/CityCell.swift`)
```swift
struct CityCell: Codable, Sendable {
    let x: Int
    let y: Int
    var zone: ZoneType
    var level: Int          // 0=unbuilt, 1-5=developed
    var hasRoadAccess: Bool // set by scanRoadAccess()
}
```

## CityGrid (`Models/CityGrid.swift`)
- `@Observable final class`
- `static size = 50` — square grid
- `cells: [[CityCell]]` — 2D array, row-major
- Key methods: `setZone`, `cell(at:)`, `hasRoadAccess`, `roadMask`, `scanRoadAccess`, `adjustLevel`
- Computed: `residentialCount`, `commercialCount`, `officeCount`

## InputMode (`Models/InputMode.swift`)
```swift
enum InputMode: Equatable {
    case inspect
    case buildRoad
    case zoneResidential
    case zoneCommercial
    case zoneOffice
    case bulldoze
}
```
- `zoneType: ZoneType?` — maps mode to zone (nil for inspect/bulldoze)

## IsometricConfig (`Models/IsometricConfig.swift`)
- Static config and math utilities
- `tileWidth: CGFloat = 80`, `tileHeight: CGFloat = 61`
- `gridToScreen(x:y:)` → screen `CGPoint`
- `screenToGrid(point:)` → grid coords
- Provides `worldBounds()`, `zPosition()`

## SpriteCatalog (`Models/SpriteCatalog.swift`)
- Static sprite resolution
- `grassTile(x:y:)` → always `"grassWhole"`
- `buildingTile(zone:level:)` → sprite name from level→index mapping tables
- `roadTile(bitmask:)` → sprite based on N/S/W/E connection bitmask
- `treeSprite(x:y:)` → pseudo-random tree variant
- `lotSprite(zone:)` → empty lot overlay for unbuilt zones

## SpriteLayer (`Models/SpriteCatalog.swift`)
```swift
enum SpriteLayer: Int {
    case ground = 0
    case road
    case lot
    case building
    case tree
}
```

## SimulationResult (`Engine/CitySimulationEngine.swift`)
```swift
struct SimulationResult {
    let playerFunds: Int
    let population: Int
    let demandResidential: Float
    let demandCommercial: Float
    let demandOffice: Float
    let upgrades: [(x: Int, y: Int, delta: Int)]
}
```

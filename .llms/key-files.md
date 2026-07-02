# Key Files Reference

## Entry Point
- `CityApp.swift:4` — `@main struct CityApp`, renders `ContentView`

## Game Orchestration
- `ContentView.swift:4-58` — Owns `scene`, `grid`, `engine` as `@State`; runs 3s tick loop; toggles between `HomeView` and game view

## Data Layer
- `CityGrid.swift:5` — `@Observable` 50×50 grid of `CityCell`; methods: `setZone`, `adjustLevel`, `scanRoadAccess`, `roadMask`
- `CityCell.swift:3` — Value type: `x`, `y`, `zone`, `level` (0-5), `hasRoadAccess`
- `ZoneType.swift:3` — 6-case enum with `displayName`, `icon`, `color`, `buildCost`

## Simulation
- `CitySimulationEngine.swift:6` — `@Observable` tick-based engine: growth (system B), finance/tax (system C), RCI demand recalculation
- `SimulationResult.swift:114` — Value struct returned by `tick()`

## Rendering (SpriteKit)
- `CityScene.swift:3` — `SKScene` subclass: 5 node grids (ground, building, road, lot, tree); `refreshAll`/`refreshCell`; touch→grid coordinate conversion; drag axis-locked placement
- `IsometricConfig.swift:3` — Grid↔screen coordinate math, tile sizing, z-ordering
- `SpriteCatalog.swift:3` — Maps zone+level to building sprite; bitmask to road sprite

## SwiftUI Wrapper
- `CitySpriteView.swift:4` — `UIViewRepresentable` wrapping `SKView`, syncs `inputMode` and `scene.size`

## UI (SwiftUI)
- `HomeView.swift:3` — Simple title + start button
- `HUDView.swift:5` — `StatsBar` (funds/population) + `BuildToolbar` (zone cards + bulldoze)

## Key Constants
- `CityGrid.size = 50` — Grid dimensions
- `IsometricConfig.tileWidth = 80`, `tileHeight = 61` — Rendered tile size
- Starting funds: `20,000`
- Tick interval: `3 seconds`

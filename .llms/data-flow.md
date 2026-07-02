# Data Flow

## Game Start
1. User taps "Start" → `ContentView.startGame()`
2. Creates `CityGrid` (50×50 all `.empty`), `CitySimulationEngine`, `CityScene`
3. `CityScene.setupScene()` → sets camera, calls `refreshAll()` → renders grass tiles

## Player Action (Build Zone / Road)
1. Touch on `SKView` → `CityScene.touchesBegan/Moved`
2. `gridPosition(from:)` converts screen point → grid coords via `IsometricConfig.screenToGrid`
3. `applyAction(at:y:)`:
   - Bulldoze: checks `engine.spend(5)`, sets zone to `.empty`, refreshes neighbors
   - Build: validates zone is `.empty`, checks cost via `engine.spend()`, calls `grid.setZone()`
   - Roads trigger neighbor refresh for road appearance
4. `refreshCell(x:y:)` removes old nodes, adds new ground/road/building/lot/tree sprites
5. Drag placement locks to X or Y axis for straight lines

## Simulation Tick (every 3s via `.task` in ContentView)
1. `engine.tick(grid:)` called on main actor
2. **System A**: `grid.scanRoadAccess()` — marks cells adjacent to roads
3. **System B**: Growth — cells with road access grow/decline based on RCI demand
4. **System C**: Finance — collects taxes (`baseTax * level * taxFactor`), subtracts road upkeep, updates population/jobs counts
5. RCI demand recalculated from job/population balance + tax impact
6. Returns `SimulationResult` with `upgrades` array
7. `scene.applyUpgrades()` calls `refreshCell` for each changed cell

## State Flow
```
Touch → CityScene.applyAction() → CityGrid.setZone()
                                  CitySimulationEngine.spend()
       → CityScene.refreshCell() → removeAllNodes() + addGround/etc.

Timer → CitySimulationEngine.tick() → CityGrid.scanRoadAccess()
                                       CityGrid.adjustLevel()
       → CityScene.applyUpgrades()  → refreshCell() per upgrade
       → ContentView updates @State vars (playerFunds, population)
       → SwiftUI re-renders HUDView
```

## Important Notes
- All simulation runs on `@MainActor`
- Grid mutations happen in place (reference type)
- Scene nodes are rebuilt from scratch per cell on each change (no diffing)
- Engine uses `@Observable` but only `playerFunds`/`population` are read by SwiftUI

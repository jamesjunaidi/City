# Project Structure

```
City/
├── CityApp.swift                  # @main SwiftUI App entry point
├── ContentView.swift              # Root view, owns core objects & game loop
│
├── Models/
│   ├── CityCell.swift             # Single tile: position, zone, level, road access
│   ├── CityGrid.swift             # 50×50 grid, zone/level mutation, road scanning
│   ├── InputMode.swift            # Enum: inspect, buildRoad, zone*, bulldoze
│   ├── IsometricConfig.swift      # Grid→screen math, tile sizing, z-ordering
│   ├── SpriteCatalog.swift        # Maps zone/level/bitmask → sprite image name
│   └── ZoneType.swift             # Enum: empty, road, residential, commercial, office, bulldoze
│
├── Engine/
│   └── CitySimulationEngine.swift  # Tick-based sim: growth, tax, RCI demand, funds
│
├── Views/
│   ├── HomeView.swift             # Title screen with Start button
│   ├── HUDView.swift              # Stats bar + build toolbar (zone cards, bulldoze)
│   ├── CityScene.swift            # SKScene: tile rendering, touch→grid, camera
│   └── CitySpriteView.swift       # UIViewRepresentable wrapping SKView
│
├── Components/                    # (empty — reusable SwiftUI subviews in HUDView)
│
├── Sprites/
│   ├── buildings/                 # 129 Kenney isometric building PNGs (000–128)
│   ├── roads/                     # 96 sprites: roads, water, trees, terrain
│   ├── tiles/                     # 128 city tile sprites (000–127)
│   └── details/                   # 11 detail sprites (000–010)
│
└── Assets.xcassets/               # App icon, accent color
```

Sprite assets are by Kenney Vleugels (CC0 1.0).

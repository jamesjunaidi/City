# Architecture Overview

GridCity is an **isometric city-building simulator** for iOS built with **SpriteKit** and **SwiftUI**. It follows a lightweight MVVM-like pattern without a formal coordinator layer.

## Tech Stack

- **SwiftUI** — App entry point, HUD, home screen, state bindings
- **SpriteKit** — Isometric tile rendering, touch handling, camera
- **Observation** (iOS 17+) — Reactive state on `CityGrid` and `CitySimulationEngine`
- **UIKit** — `SKView` wrapped via `UIViewRepresentable`

## Pattern

```
SwiftUI Views  ──>  CityScene (SKScene)  ──>  CityGrid (data)
                       │                           │
                       │                    CitySimulationEngine (logic)
                       │                           │
                       ▼                           ▼
                  SpriteKit nodes           Observable properties
```

- `ContentView` owns the three core objects (`CityScene`, `CityGrid`, `CitySimulationEngine`) as `@State`
- `CityScene` holds direct references to the grid and engine for tile placement and rendering
- A background `.task` runs the simulation tick every 3 seconds, then pushes visual updates to the scene

## Key Design Decisions

- **No persistence or save/load** yet
- **No test targets** currently configured
- **Single-screen**: home → game, no navigation stack
- **Drag-to-place** roads/zones along locked axes (horizontal/vertical in isometric space)
- **No undo/redo** system
- Touch handling is entirely within `CityScene` (not SwiftUI gestures)

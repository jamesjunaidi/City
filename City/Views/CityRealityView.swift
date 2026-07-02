import SwiftUI
import RealityKit

// Camera constants — kept in sync with rayPlaneIntersect.
private let kCameraPosition = SIMD3<Float>(0, 40, 0.01)
private let kCameraFovYDeg: Float = 45

// Holds RealityKit object references that must be created inside the make closure.
private final class SceneState: @unchecked Sendable {
    var buildingsRoot: Entity?
}

struct CityRealityView: View {
    var grid: CityGrid
    @Binding var inputMode: InputMode
    let engine: CitySimulationEngine

    @State private var scene = SceneState()
    @State private var touchedCells: Set<Int> = []

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                let gridSize = Float(CityGrid.size) * CityGrid.cellSize

                let floor = ModelEntity(
                    mesh: .generatePlane(width: gridSize, depth: gridSize),
                    materials: [SimpleMaterial(color: .init(white: 0.18, alpha: 1),
                                               isMetallic: false)]
                )
                floor.name = "floor"

                let buildings = Entity()
                scene.buildingsRoot = buildings

                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = kCameraFovYDeg
                camera.position = kCameraPosition
                camera.look(at: .zero, from: camera.position, relativeTo: nil)

                let light = Entity()
                var lightComp = DirectionalLightComponent()
                lightComp.intensity = 2_500
                light.components.set(lightComp)
                light.orientation = simd_quatf(angle: -.pi / 3,
                                               axis: normalize(SIMD3<Float>(1, 0.2, 0)))

                let root = Entity()
                root.addChild(floor)
                root.addChild(buildings)
                root.addChild(camera)
                root.addChild(light)
                content.add(root)
            } update: { content in
                guard let root = scene.buildingsRoot else { return }
                rebuildEntities(from: root, grid: grid)
            }
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(at: value.location, viewSize: geo.size)
                            }
                            .onEnded { _ in
                                touchedCells.removeAll()
                            }
                    )
            }
        }
        .task {
            await runHeartbeat()
        }
    }

    // MARK: - Ray-plane intersection

    private func rayPlaneIntersect(screenPos: CGPoint, viewSize: CGSize) -> SIMD3<Float>? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        let nx =  Float(screenPos.x / viewSize.width)  * 2 - 1
        let ny = -(Float(screenPos.y / viewSize.height) * 2 - 1)
        let aspect = Float(viewSize.width / viewSize.height)

        let forward = normalize(-kCameraPosition)
        let right   = normalize(cross(forward, SIMD3<Float>(0, 1, 0)))
        let up      = normalize(cross(right, forward))

        let tanHalfFov = tan((kCameraFovYDeg * .pi / 180) / 2)
        let rayDir = normalize(forward
                               + right * (nx * aspect * tanHalfFov)
                               + up    * (ny * tanHalfFov))

        guard abs(rayDir.y) > 1e-6 else { return nil }
        let t = -kCameraPosition.y / rayDir.y
        guard t > 0 else { return nil }

        return kCameraPosition + t * rayDir
    }

    // MARK: - Placement & Bulldoze

    private func handleDrag(at screenPos: CGPoint, viewSize: CGSize) {
        guard inputMode != .inspect else { return }
        guard let worldPos = rayPlaneIntersect(screenPos: screenPos, viewSize: viewSize) else { return }
        guard let coord = grid.gridCoordinate(from: worldPos) else { return }

        let cellId = coord.y * CityGrid.size + coord.x
        guard !touchedCells.contains(cellId) else { return }
        touchedCells.insert(cellId)

        applyAction(at: coord.x, y: coord.y)
    }

    private func applyAction(at x: Int, y: Int) {
        if inputMode == .bulldoze {
            let cell = grid.cell(at: x, y: y)
            guard let cell, cell.zone != .empty, cell.zone != .road else { return }
            guard engine.spend(5) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
            removeBuilding(at: x, y: y)
            grid.setZone(.empty, at: x, y: y)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }

        guard let zoneType = inputMode.zoneType else { return }
        guard grid.cell(at: x, y: y)?.zone == .empty else { return }

        let cost = zoneType.buildCost
        if cost > 0 {
            guard engine.spend(cost) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
        }
        grid.setZone(zoneType, at: x, y: y)
        if zoneType == .road {
            spawnRoadEntity(at: x, y: y)
            updateAdjacentRoads(at: x, y: y)
        } else {
            spawnLotMarker(at: x, y: y, zone: zoneType)
        }
    }

    private func spawnLotMarker(at x: Int, y: Int, zone: ZoneType) {
        guard let root = scene.buildingsRoot else { return }
        let pos = grid.worldPosition(for: x, y: y)

        let mesh = MeshResource.generatePlane(width: CityGrid.cellSize * 0.9,
                                              depth: CityGrid.cellSize * 0.9)
        let baseColor = zoneColor(zone)
        let tinted = baseColor.withAlphaComponent(0.3)
        let material = SimpleMaterial(color: tinted, isMetallic: false)

        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name     = "lotmarker_\(x)_\(y)"
        entity.position = SIMD3<Float>(pos.x, 0.01, pos.z)
        root.addChild(entity)
    }

    private func removeLotMarker(at x: Int, y: Int) {
        guard let root = scene.buildingsRoot else { return }
        root.children.first { $0.name == "lotmarker_\(x)_\(y)" }?.removeFromParent()
    }

    // MARK: - Road bitmasking

    private func roadBitmask(at x: Int, y: Int) -> Int {
        var mask = 0
        if grid.cell(at: x, y: y - 1)?.zone == .road { mask |= 1 } // N
        if grid.cell(at: x, y: y + 1)?.zone == .road { mask |= 2 } // S
        if grid.cell(at: x - 1, y: y)?.zone == .road { mask |= 4 } // W
        if grid.cell(at: x + 1, y: y)?.zone == .road { mask |= 8 } // E
        return mask
    }

    private func spawnRoadEntity(at x: Int, y: Int) {
        guard let root = scene.buildingsRoot else { return }
        let pos = grid.worldPosition(for: x, y: y)

        if let existing = findEntity(atX: x, y: y, in: root) {
            existing.removeFromParent()
        }

        let roadEntity = Entity()
        roadEntity.name = "building_\(x)_\(y)"
        roadEntity.position = pos
        roadEntity.components[BuildingComponent.self] = BuildingComponent(
            type: .road, gridX: x, gridY: y
        )

        let roadColor = UIColor(white: 0.4, alpha: 1)
        let roadMat = SimpleMaterial(color: roadColor, isMetallic: false)
        let roadWidth: Float = 0.6
        let armLength: Float = 0.2

        let center = ModelEntity(
            mesh: .generatePlane(width: roadWidth, depth: roadWidth),
            materials: [roadMat]
        )
        center.position = SIMD3<Float>(0, 0.01, 0)
        roadEntity.addChild(center)

        let mask = roadBitmask(at: x, y: y)

        if mask & 1 != 0 {
            let arm = ModelEntity(
                mesh: .generatePlane(width: roadWidth, depth: armLength),
                materials: [roadMat]
            )
            arm.position = SIMD3<Float>(0, 0.01, -0.4)
            roadEntity.addChild(arm)
        }
        if mask & 2 != 0 {
            let arm = ModelEntity(
                mesh: .generatePlane(width: roadWidth, depth: armLength),
                materials: [roadMat]
            )
            arm.position = SIMD3<Float>(0, 0.01, 0.4)
            roadEntity.addChild(arm)
        }
        if mask & 4 != 0 {
            let arm = ModelEntity(
                mesh: .generatePlane(width: armLength, depth: roadWidth),
                materials: [roadMat]
            )
            arm.position = SIMD3<Float>(-0.4, 0.01, 0)
            roadEntity.addChild(arm)
        }
        if mask & 8 != 0 {
            let arm = ModelEntity(
                mesh: .generatePlane(width: armLength, depth: roadWidth),
                materials: [roadMat]
            )
            arm.position = SIMD3<Float>(0.4, 0.01, 0)
            roadEntity.addChild(arm)
        }

        root.addChild(roadEntity)
    }

    private func updateAdjacentRoads(at x: Int, y: Int) {
        let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
        for (nx, ny) in neighbors {
            if grid.cell(at: nx, y: ny)?.zone == .road {
                spawnRoadEntity(at: nx, y: ny)
            }
        }
    }

    private func spawnBuilding(at x: Int, y: Int, zone: ZoneType) {
        guard let root = scene.buildingsRoot else { return }
        let pos = grid.worldPosition(for: x, y: y)

        let (mesh, halfH): (MeshResource, Float)
        switch zone {
        case .residential:
            mesh  = .generateBox(width: 0.7, height: 0.8, depth: 0.7);  halfH = 0.4
        case .commercial:
            mesh  = .generateBox(width: 0.8, height: 1.2, depth: 0.8);  halfH = 0.6
        case .office:
            mesh  = .generateBox(width: 0.8, height: 1.2, depth: 0.8);  halfH = 0.6
        case .road, .empty, .bulldoze:
            return
        }

        let entity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: zoneColor(zone), isMetallic: false)]
        )
        entity.name     = "building_\(x)_\(y)"
        entity.position = SIMD3<Float>(pos.x, halfH, pos.z)
        entity.components[BuildingComponent.self] = BuildingComponent(
            type: zone, gridX: x, gridY: y
        )
        entity.scale = .zero
        root.addChild(entity)

        entity.move(
            to: Transform(scale: .one, rotation: entity.orientation,
                          translation: entity.position),
            relativeTo: entity.parent,
            duration: 0.25,
            timingFunction: .easeOut
        )
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func removeBuilding(at x: Int, y: Int) {
        guard let root = scene.buildingsRoot else { return }
        if let entity = findEntity(atX: x, y: y, in: root) {
            entity.removeFromParent()
        }
        removeLotMarker(at: x, y: y)
        if grid.cell(at: x, y: y)?.zone == .road {
            updateAdjacentRoads(at: x, y: y)
        }
    }

    private func findEntity(atX x: Int, y: Int, in root: Entity) -> Entity? {
        for child in root.children {
            guard let comp = child.components[BuildingComponent.self],
                  comp.gridX == x, comp.gridY == y else { continue }
            return child
        }
        return nil
    }

    // MARK: - Entity rebuild (survives view recreation)

    private func rebuildEntities(from root: Entity, grid: CityGrid) {
        let existing = root.children.compactMap { child -> (Int, Int)? in
            guard let comp = child.components[BuildingComponent.self] else { return nil }
            return (comp.gridX, comp.gridY)
        }

        let markerNames = Set(root.children.compactMap { child -> String? in
            child.name.hasPrefix("lotmarker_") ? child.name : nil
        })

        for x in 0..<CityGrid.size {
            for y in 0..<CityGrid.size {
                let cell = grid.cells[x][y]
                let markerName = "lotmarker_\(x)_\(y)"

                if cell.zone != .empty, cell.zone != .road, cell.zone != .bulldoze, cell.level == 0 {
                    if !markerNames.contains(markerName) {
                        spawnLotMarker(at: x, y: y, zone: cell.zone)
                    }
                    continue
                }

                guard cell.level > 0 || cell.zone == .road else { continue }
                if !existing.contains(where: { $0 == (x, y) }) {
                    if cell.zone == .road {
                        spawnRoadEntity(at: x, y: y)
                    } else {
                        spawnBuilding(at: x, y: y, zone: cell.zone)
                        if cell.level > 1 {
                            let scale = pow(1.15, Float(cell.level - 1))
                            if let entity = findEntity(atX: x, y: y, in: root) {
                                entity.scale = SIMD3<Float>(repeating: scale)
                            }
                        }
                    }
                } else if cell.zone == .road {
                    // Refresh road visuals — neighbors may have changed
                    spawnRoadEntity(at: x, y: y)
                }
            }
        }
    }

    // MARK: - Simulation heartbeat

    private func runHeartbeat() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            let result = engine.tick(grid: grid)
            for upgrade in result.upgrades {
                if upgrade.delta > 0 {
                    let cell = grid.cell(at: upgrade.x, y: upgrade.y)
                    if let cell, cell.level == 1 {
                        removeLotMarker(at: upgrade.x, y: upgrade.y)
                        spawnBuilding(at: upgrade.x, y: upgrade.y, zone: cell.zone)
                    } else {
                        animateLevelChange(at: upgrade.x, y: upgrade.y, delta: 1)
                    }
                } else {
                    let cell = grid.cell(at: upgrade.x, y: upgrade.y)
                    if let cell, cell.level == 0 {
                        removeBuilding(at: upgrade.x, y: upgrade.y)
                    } else {
                        animateLevelChange(at: upgrade.x, y: upgrade.y, delta: -1)
                    }
                }
            }
        }
    }

    private func animateLevelChange(at x: Int, y: Int, delta: Int) {
        guard let root = scene.buildingsRoot,
              let entity = findEntity(atX: x, y: y, in: root)
        else { return }

        let scaleFactor: Float = delta > 0 ? 1.15 : (1.0 / 1.15)
        let grown = entity.scale * scaleFactor
        entity.move(
            to: Transform(scale: grown, rotation: entity.orientation,
                          translation: entity.position),
            relativeTo: entity.parent,
            duration: 0.4,
            timingFunction: .easeOut
        )
    }

    // MARK: - Color helper (iOS deployment-safe)

    private func zoneColor(_ zone: ZoneType) -> UIColor {
        #if canImport(UIKit)
        if #available(iOS 17.0, *) {
            return UIColor(zone.color)
        } else {
            return .systemGray
        }
        #else
        return .systemGray
        #endif
    }
}

import SwiftUI
import RealityKit

// Camera constants — kept in sync with rayPlaneIntersect.
private let kCameraPosition = SIMD3<Float>(0, 22, 38)
private let kCameraFovYDeg: Float = 50

// Holds RealityKit object references that must be created inside the make closure.
private final class SceneState: @unchecked Sendable {
    var buildingsRoot: Entity?
}

struct CityRealityView: View {
    var grid: CityGrid
    @Binding var selectedZone: ZoneType
    let engine: CitySimulationEngine

    @State private var scene = SceneState()

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
                let pitch = -atan2(kCameraPosition.y, kCameraPosition.z)
                camera.orientation = simd_quatf(angle: pitch,
                                                axis: SIMD3<Float>(1, 0, 0))

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
                    .onTapGesture { screenPos in
                        guard let worldPos = rayPlaneIntersect(screenPos: screenPos,
                                                               viewSize: geo.size)
                        else { return }
                        handleTap(at: worldPos)
                    }
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

    private func handleTap(at worldPos: SIMD3<Float>) {
        guard selectedZone != .empty else { return }
        guard let coord = grid.gridCoordinate(from: worldPos) else { return }

        if selectedZone == .bulldoze {
            let cell = grid.cell(at: coord.x, y: coord.y)
            guard let cell, cell.zone != .empty, cell.zone != .road else { return }
            removeBuilding(at: coord.x, y: coord.y)
            grid.setZone(.empty, at: coord.x, y: coord.y)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            return
        }

        guard grid.cell(at: coord.x, y: coord.y)?.zone == .empty else { return }

        let cost = selectedZone.buildCost
        if cost > 0 {
            guard engine.spend(cost) else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                return
            }
        }
        grid.setZone(selectedZone, at: coord.x, y: coord.y)
        spawnBuilding(at: coord.x, y: coord.y, zone: selectedZone)
    }

    private func spawnBuilding(at x: Int, y: Int, zone: ZoneType) {
        guard let root = scene.buildingsRoot else { return }
        let pos = grid.worldPosition(for: x, y: y)

        let (mesh, halfH): (MeshResource, Float)
        switch zone {
        case .road:
            mesh  = .generatePlane(width: CityGrid.cellSize * 0.95,
                                   depth: CityGrid.cellSize * 0.95)
            halfH = 0.02
        case .residential:
            mesh  = .generateBox(width: 0.7, height: 0.8, depth: 0.7);  halfH = 0.4
        case .commercial:
            mesh  = .generateBox(width: 0.8, height: 1.2, depth: 0.8);  halfH = 0.6
        case .office:
            mesh  = .generateBox(width: 0.8, height: 1.2, depth: 0.8);  halfH = 0.6
        case .empty, .bulldoze:
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
        guard let entity = findEntity(atX: x, y: y, in: root) else { return }
        entity.removeFromParent()
    }

    private func findEntity(atX x: Int, y: Int, in root: Entity) -> ModelEntity? {
        for child in root.children {
            if let model = child as? ModelEntity,
               let comp = model.components[BuildingComponent.self],
               comp.gridX == x, comp.gridY == y {
                return model
            }
        }
        return nil
    }

    // MARK: - Entity rebuild (survives view recreation)

    private func rebuildEntities(from root: Entity, grid: CityGrid) {
        let existing = root.children.compactMap { child -> (Int, Int)? in
            guard let model = child as? ModelEntity,
                  let comp = model.components[BuildingComponent.self] else { return nil }
            return (comp.gridX, comp.gridY)
        }

        for x in 0..<CityGrid.size {
            for y in 0..<CityGrid.size {
                let cell = grid.cells[x][y]
                guard cell.zone != .empty, cell.zone != .road, cell.zone != .bulldoze else { continue }
                if !existing.contains(where: { $0 == (x, y) }) {
                    spawnBuilding(at: x, y: y, zone: cell.zone)
                    if cell.level > 0 {
                        let scale = pow(1.15, Float(cell.level))
                        if let entity = findEntity(atX: x, y: y, in: root) {
                            entity.scale = SIMD3<Float>(repeating: scale)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Simulation heartbeat

    private func runHeartbeat() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            let result = engine.tick(grid: grid)
            for upgrade in result.upgrades {
                upgradeBuilding(at: upgrade.x, y: upgrade.y)
            }
        }
    }

    private func upgradeBuilding(at x: Int, y: Int) {
        guard let root = scene.buildingsRoot,
              let entity = findEntity(atX: x, y: y, in: root)
        else { return }

        let grown = entity.scale * 1.15
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

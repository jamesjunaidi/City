import SwiftUI
import RealityKit

// Camera constants — kept in sync with rayPlaneIntersect.
private let kCameraPosition = SIMD3<Float>(0, 22, 38)
private let kCameraFovYDeg: Float = 50

// Holds RealityKit object references that must be created inside the make closure.
// Using a class so @State owns the box, not the entities themselves.
private final class SceneState: @unchecked Sendable {
    var buildingsRoot: Entity?
}

struct CityRealityView: View {
    var grid: CityGrid
    @Binding var selectedZone: ZoneType
    let engine: CitySimulationEngine
    let onSimulationResult: (SimulationResult) -> Void

    @State private var scene = SceneState()

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                // ⚠️ ALL Entity/Material creation must happen here —
                // RealityKit's runtime is not yet live when @State initialises.

                let gridSize = Float(CityGrid.size) * CityGrid.cellSize

                // Floor
                let floor = ModelEntity(
                    mesh: .generatePlane(width: gridSize, depth: gridSize),
                    materials: [SimpleMaterial(color: .init(white: 0.18, alpha: 1),
                                               isMetallic: false)]
                )
                floor.name = "floor"

                // Buildings container — stored so spawnBuilding can reach it.
                let buildings = Entity()
                scene.buildingsRoot = buildings

                // Isometric camera (~30° elevation).
                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = kCameraFovYDeg
                camera.position = kCameraPosition
                let pitch = -atan2(kCameraPosition.y, kCameraPosition.z)
                camera.orientation = simd_quatf(angle: pitch,
                                                axis: SIMD3<Float>(1, 0, 0))

                // Directional light
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

    // MARK: - Placement

    private func handleTap(at worldPos: SIMD3<Float>) {
        guard selectedZone != .empty else { return }
        guard let coord = grid.gridCoordinate(from: worldPos) else { return }
        guard grid.cell(at: coord.x, y: coord.y)?.zone == .empty else { return }

        let zone = selectedZone
        Task { @MainActor in
            let cost = zone.buildCost
            if cost > 0 { guard await engine.spend(cost) else { return } }
            grid.setZone(zone, at: coord.x, y: coord.y)
            spawnBuilding(at: coord.x, y: coord.y, zone: zone)
        }
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
        case .industrial:
            mesh  = .generateBox(width: 0.85, height: 1.0, depth: 0.85); halfH = 0.5
        case .empty:
            return
        }

        let entity = ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: UIColor(zone.color), isMetallic: false)]
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

    // MARK: - Simulation heartbeat

    private func runHeartbeat() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            let snapshot = grid.cells
            let result   = await engine.tick(cells: snapshot)
            for upgrade in result.upgrades {
                grid.upgradeCell(at: upgrade.x, y: upgrade.y)
                upgradeBuilding(at: upgrade.x, y: upgrade.y)
            }
            onSimulationResult(result)
        }
    }

    private func upgradeBuilding(at x: Int, y: Int) {
        guard let root   = scene.buildingsRoot,
              let entity = root.findEntity(named: "building_\(x)_\(y)") as? ModelEntity
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
}

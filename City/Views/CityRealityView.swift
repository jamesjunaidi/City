import SwiftUI
import RealityKit

// Camera constants — kept in sync between setupScene and rayPlaneIntersect.
// Position (0, 22, 38) gives ~30° elevation: enough to see building sides
// while still showing a wide city view.
private let kCameraPosition = SIMD3<Float>(0, 22, 38)
private let kCameraFovYDeg: Float = 50

struct CityRealityView: View {
    var grid: CityGrid
    @Binding var selectedZone: ZoneType
    let engine: CitySimulationEngine
    let onSimulationResult: (SimulationResult) -> Void

    // Persists the buildings container across view re-renders.
    @State private var buildingsRoot = Entity()

    var body: some View {
        GeometryReader { geo in
            RealityView { content in
                // RealityViewContent's concrete type is inferred by the compiler;
                // we must not name it explicitly in a separate function signature.
                let gridSize = Float(CityGrid.size) * CityGrid.cellSize

                // Floor
                let floorMesh = MeshResource.generatePlane(width: gridSize, depth: gridSize)
                var floorMat = PhysicallyBasedMaterial()
                floorMat.baseColor = .init(tint: .init(white: 0.18, alpha: 1))
                floorMat.roughness = .init(floatLiteral: 0.95)
                let floor = ModelEntity(mesh: floorMesh, materials: [floorMat])
                floor.name = "floor"

                // Camera at ~30° elevation so building sides are visible.
                // Rotation angle = atan2(22, 38) ≈ 30° → rotate -30° around X.
                let camera = PerspectiveCamera()
                camera.camera.fieldOfViewInDegrees = kCameraFovYDeg
                camera.position = kCameraPosition
                let pitch = -atan2(kCameraPosition.y, kCameraPosition.z)
                camera.orientation = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))

                // Directional light from above-left.
                let lightEntity = Entity()
                var lightComp = DirectionalLightComponent()
                lightComp.intensity = 2_500
                lightEntity.components.set(lightComp)
                lightEntity.orientation = simd_quatf(
                    angle: -.pi / 3,
                    axis: normalize(SIMD3<Float>(1, 0.2, 0))
                )

                // AnchorEntity(world:) requires an active ARKit session and
                // will fault in a non-AR RealityView. Use a plain Entity instead.
                let root = Entity()
                root.addChild(floor)
                root.addChild(buildingsRoot)
                root.addChild(camera)
                root.addChild(lightEntity)
                content.add(root)
            }
            // Tap is handled via an invisible overlay so we can receive a plain
            // CGPoint and unproject it ourselves into the y=0 world plane.
            .overlay {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { screenPos in
                        guard let worldPos = rayPlaneIntersect(
                            screenPos: screenPos,
                            viewSize: geo.size
                        ) else { return }
                        handleTap(at: worldPos)
                    }
            }
        }
        .task {
            await runHeartbeat()
        }
    }

    // MARK: - Ray-plane intersection

    /// Projects a 2-D screen tap into the y = 0 world plane.
    /// Uses the same camera constants as setupScene.
    private func rayPlaneIntersect(screenPos: CGPoint, viewSize: CGSize) -> SIMD3<Float>? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }

        // NDC coords: x ∈ (-1, 1) left→right, y ∈ (-1, 1) bottom→top.
        let nx =  Float(screenPos.x / viewSize.width)  * 2 - 1
        let ny = -(Float(screenPos.y / viewSize.height) * 2 - 1)
        let aspect = Float(viewSize.width / viewSize.height)

        // Camera axes matching the orientation in setupScene.
        // forward = normalize((0,0,0) - cameraPosition)
        let forward = normalize(-kCameraPosition)                     // (0, -1/√2, -1/√2)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let right   = normalize(cross(forward, worldUp))              // (1, 0, 0)
        let up      = normalize(cross(right, forward))                // camera's up vector

        let tanHalfFov = tan((kCameraFovYDeg * .pi / 180) / 2)
        let rayDir = normalize(
            forward
            + right * (nx * aspect * tanHalfFov)
            + up    * (ny * tanHalfFov)
        )

        // Intersect with the y = 0 ground plane: P = camPos + t * rayDir
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
            if cost > 0 {
                guard await engine.spend(cost) else { return }
            }
            grid.setZone(zone, at: coord.x, y: coord.y)
            spawnBuilding(at: coord.x, y: coord.y, zone: zone)
        }
    }

    private func spawnBuilding(at x: Int, y: Int, zone: ZoneType) {
        let pos = grid.worldPosition(for: x, y: y)

        let (mesh, halfH): (MeshResource, Float)
        switch zone {
        case .road:
            mesh  = MeshResource.generatePlane(
                width: CityGrid.cellSize * 0.95,
                depth: CityGrid.cellSize * 0.95
            )
            halfH = 0.02
        case .residential:
            mesh  = MeshResource.generateBox(width: 0.7, height: 0.8, depth: 0.7)
            halfH = 0.4
        case .commercial:
            mesh  = MeshResource.generateBox(width: 0.8, height: 1.2, depth: 0.8)
            halfH = 0.6
        case .industrial:
            mesh  = MeshResource.generateBox(width: 0.85, height: 1.0, depth: 0.85)
            halfH = 0.5
        case .empty:
            return
        }

        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(zone.color))
        mat.roughness = .init(floatLiteral: 0.7)
        mat.metallic  = .init(floatLiteral: zone == .commercial ? 0.3 : 0.0)

        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name     = "building_\(x)_\(y)"
        entity.position = SIMD3<Float>(pos.x, halfH, pos.z)
        entity.components[BuildingComponent.self] = BuildingComponent(
            type: zone, gridX: x, gridY: y
        )
        entity.scale = .zero
        buildingsRoot.addChild(entity)

        // "Pop" animation on placement.
        entity.move(
            to: Transform(scale: .one, rotation: entity.orientation, translation: entity.position),
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
            // Pass a value-type snapshot — [[CityCell]] is Sendable, CityGrid is not.
            let snapshot = grid.cells
            let result = await engine.tick(cells: snapshot)
            for upgrade in result.upgrades {
                grid.upgradeCell(at: upgrade.x, y: upgrade.y)
                upgradeBuilding(at: upgrade.x, y: upgrade.y)
            }
            onSimulationResult(result)
        }
    }

    private func upgradeBuilding(at x: Int, y: Int) {
        guard let entity = buildingsRoot.findEntity(named: "building_\(x)_\(y)") as? ModelEntity else { return }
        let grown = entity.scale * 1.15
        entity.move(
            to: Transform(scale: grown, rotation: entity.orientation, translation: entity.position),
            relativeTo: entity.parent,
            duration: 0.4,
            timingFunction: .easeOut
        )
    }
}

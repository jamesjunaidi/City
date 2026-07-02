import SpriteKit

class CityScene: SKScene {
    let grid: CityGrid
    let engine: CitySimulationEngine
    var inputMode: InputMode = .inspect

    private var groundNodes: [[SKSpriteNode?]]
    private var buildingNodes: [[SKSpriteNode?]]
    private var roadNodes: [[SKSpriteNode?]]
    private var lotNodes: [[SKSpriteNode?]]
    private var treeNodes: [[SKSpriteNode?]]

    private var touchedCells: Set<Int> = []
    private var gridCenterOffset: CGPoint = .zero
    private var camScale: CGFloat = 1

    override init(size: CGSize) {
        grid = CityGrid()
        engine = CitySimulationEngine()
        let sz = IsometricConfig.gridSize
        groundNodes   = Array(repeating: Array(repeating: nil, count: sz), count: sz)
        buildingNodes = Array(repeating: Array(repeating: nil, count: sz), count: sz)
        roadNodes     = Array(repeating: Array(repeating: nil, count: sz), count: sz)
        lotNodes      = Array(repeating: Array(repeating: nil, count: sz), count: sz)
        treeNodes     = Array(repeating: Array(repeating: nil, count: sz), count: sz)
        super.init(size: size)
        setupScene()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshAll() {
        for x in 0..<IsometricConfig.gridSize {
            for y in 0..<IsometricConfig.gridSize {
                refreshCell(x: x, y: y)
            }
        }
    }

    func refreshCell(x: Int, y: Int) {
        guard let cell = grid.cell(at: x, y: y) else { return }
        removeAllNodes(at: x, y: y)

        switch cell.zone {
        case .empty:
            addGround(x: x, y: y)
            let hasRoad = grid.hasRoadAccess(at: x, y: y)
            if hasRoad, (x * 31 + y * 71) % 100 < 30 {
                addTree(x: x, y: y)
            }

        case .road:
            let bitmask = grid.roadMask(at: x, y: y)
            addRoad(x: x, y: y, bitmask: bitmask)
            addGround(x: x, y: y)

        default:
            if cell.level == 0 {
                addGround(x: x, y: y)
                addLot(x: x, y: y)
            } else {
                addGround(x: x, y: y)
                addBuilding(x: x, y: y, zone: cell.zone, level: cell.level)
            }
        }
    }

    func applyUpgrades(_ upgrades: [(x: Int, y: Int, delta: Int)]) {
        for u in upgrades {
            refreshCell(x: u.x, y: u.y)
        }
    }

    // MARK: – Setup

    private func setupScene() {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(red: 0.5, green: 0.55, blue: 0.4, alpha: 1)

        let cam = SKCameraNode()
        camera = cam
        addChild(cam)

        gridCenterOffset = IsometricConfig.gridToScreen(
            x: IsometricConfig.gridSize / 2,
            y: IsometricConfig.gridSize / 2
        )

        let bounds = IsometricConfig.worldBounds()
        let scaleW = size.width / bounds.width
        let scaleH = size.height / bounds.height
        camScale = min(scaleW, scaleH) * 0.85
        cam.setScale(camScale)

        refreshAll()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard camera != nil else { return }
        let bounds = IsometricConfig.worldBounds()
        let scaleW = size.width / bounds.width
        let scaleH = size.height / bounds.height
        camScale = min(scaleW, scaleH) * 0.85
        camera!.setScale(camScale)
    }

    // MARK: – Spawn helpers

    private func addGround(x: Int, y: Int) {
        let node = makeSprite(name: SpriteCatalog.grassTile(x: x, y: y), layer: .ground, x: x, y: y)
        groundNodes[x][y] = node
        addChild(node)
    }

    private func addRoad(x: Int, y: Int, bitmask: Int) {
        let node = makeSprite(name: SpriteCatalog.roadTile(bitmask: bitmask), layer: .road, x: x, y: y)
        roadNodes[x][y] = node
        addChild(node)
    }

    private func addBuilding(x: Int, y: Int, zone: ZoneType, level: Int) {
        let node = makeSprite(name: SpriteCatalog.buildingTile(zone: zone, level: level),
                              layer: .building, x: x, y: y, anchor: CGPoint(x: 0.5, y: 0))
        buildingNodes[x][y] = node
        addChild(node)
    }

    private func addLot(x: Int, y: Int) {
        let node = makeSprite(name: SpriteCatalog.lotSprite(), layer: .lot, x: x, y: y)
        node.alpha = 0.5
        lotNodes[x][y] = node
        addChild(node)
    }

    private func addTree(x: Int, y: Int) {
        let node = makeSprite(name: SpriteCatalog.treeSprite(x: x, y: y),
                              layer: .tree, x: x, y: y, anchor: CGPoint(x: 0.5, y: 0))
        treeNodes[x][y] = node
        addChild(node)
    }

    private func makeSprite(name: String, layer: SpriteLayer, x: Int, y: Int,
                            anchor: CGPoint = CGPoint(x: 0.5, y: 0.5)) -> SKSpriteNode
    {
        let tex = SKTexture(imageNamed: name)
        let node = SKSpriteNode(texture: tex)
        let iso = IsometricConfig.gridToScreen(x: x, y: y)
        var posX = iso.x - gridCenterOffset.x
        var posY = -(iso.y - gridCenterOffset.y)

        if anchor.y < 0.5 {
            posY -= IsometricConfig.tileHeight / 2
        }

        node.position = CGPoint(x: posX, y: posY)
        node.anchorPoint = anchor
        node.zPosition = IsometricConfig.zPosition(x: x, y: y, layer: layer.rawValue)

        let sx = IsometricConfig.tileWidth / IsometricConfig.nativeTileWidth
        node.setScale(sx)
        return node
    }

    private func removeAllNodes(at x: Int, y: Int) {
        if let n = groundNodes[x][y] { n.removeFromParent(); groundNodes[x][y] = nil }
        if let n = buildingNodes[x][y] { n.removeFromParent(); buildingNodes[x][y] = nil }
        if let n = roadNodes[x][y] { n.removeFromParent(); roadNodes[x][y] = nil }
        if let n = lotNodes[x][y] { n.removeFromParent(); lotNodes[x][y] = nil }
        if let n = treeNodes[x][y] { n.removeFromParent(); treeNodes[x][y] = nil }
    }

    // MARK: – Actions

    private func applyAction(at x: Int, y: Int) {
        if inputMode == .bulldoze {
            guard let cell = grid.cell(at: x, y: y), cell.zone != .empty, cell.zone != .road,
                  engine.spend(5) else { return }
            grid.setZone(.empty, at: x, y: y)
            refreshCell(x: x, y: y)
            return
        }

        guard let zoneType = inputMode.zoneType,
              grid.cell(at: x, y: y)?.zone == .empty else { return }

        let cost = zoneType.buildCost
        if cost > 0 {
            guard engine.spend(cost) else { return }
        }

        grid.setZone(zoneType, at: x, y: y)

        if zoneType == .road {
            let neighbors = [(x, y-1), (x, y+1), (x-1, y), (x+1, y)]
            for (nx, ny) in neighbors {
                guard nx >= 0, nx < CityGrid.size, ny >= 0, ny < CityGrid.size else { continue }
                guard grid.cell(at: nx, y: ny)?.zone == .road else { continue }
                refreshCell(x: nx, y: ny)
            }
        }

        refreshCell(x: x, y: y)
    }

    // MARK: – Touches

    private func gridPosition(from touch: UITouch) -> (x: Int, y: Int)? {
        let viewLoc = touch.location(in: view!)
        let sceneLoc = convertPoint(fromView: viewLoc)
        let isoPt = CGPoint(x: sceneLoc.x + gridCenterOffset.x,
                            y: -(sceneLoc.y - gridCenterOffset.y))
        let (gx, gy) = IsometricConfig.screenToGrid(point: isoPt)
        guard gx >= 0, gx < IsometricConfig.gridSize,
              gy >= 0, gy < IsometricConfig.gridSize else { return nil }
        return (gx, gy)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let (gx, gy) = gridPosition(from: touch) else { return }
        touchedCells = [gy * IsometricConfig.gridSize + gx]
        applyAction(at: gx, y: gy)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let (gx, gy) = gridPosition(from: touch) else { return }
        let cellId = gy * IsometricConfig.gridSize + gx
        guard !touchedCells.contains(cellId) else { return }
        touchedCells.insert(cellId)
        applyAction(at: gx, y: gy)
    }
}

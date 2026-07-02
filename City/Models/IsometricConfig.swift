import CoreGraphics

enum IsometricConfig {
    static let gridSize: Int = CityGrid.size

    static let nativeTileWidth: CGFloat = 132
    static let nativeTileHeight: CGFloat = 101

    static let tileWidth: CGFloat = 80
    static let tileHeight: CGFloat = 60

    static func gridToScreen(x: Int, y: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(x - y) * tileWidth / 2,
            y: CGFloat(x + y) * tileHeight / 4
        )
    }

    static func screenToGrid(point: CGPoint) -> (x: Int, y: Int) {
        let px = point.x / (tileWidth / 2)
        let py = point.y / (tileHeight / 4)
        let gx = Int(round((px + py) / 2))
        let gy = Int(round((py - px) / 2))
        return (gx, gy)
    }

    static func worldBounds() -> CGRect {
        let minPt = gridToScreen(x: 0, y: gridSize)
        let maxPt = gridToScreen(x: gridSize, y: 0)
        return CGRect(
            x: minPt.x - tileWidth,
            y: minPt.y - tileHeight,
            width: maxPt.x - minPt.x + tileWidth * 2,
            height: maxPt.y - minPt.y + tileHeight * 2
        )
    }

    static func zPosition(x: Int, y: Int, layer: Int) -> CGFloat {
        CGFloat(x + y) * 10 + CGFloat(layer)
    }
}

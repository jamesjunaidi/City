import RealityKit

struct BuildingComponent: Component, Codable {
    var type: ZoneType
    var inhabitants: Int = 0
    var efficiency: Float = 1.0
    var gridX: Int = 0
    var gridY: Int = 0
}

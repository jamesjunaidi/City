import Foundation

struct CityCell: Codable, Sendable {
    let x: Int
    let y: Int
    var zone: ZoneType
    var level: Int = 0       // 0 = unbuilt, 1-5 = built/developed
    var hasRoadAccess: Bool = false
}

import Foundation

struct CityCell: Codable, Sendable {
    let x: Int
    let y: Int
    var zone: ZoneType
    var level: Int = 0
    var lastTaxCollection: Date = Date()
}

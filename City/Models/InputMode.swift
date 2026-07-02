import Foundation

enum InputMode: Equatable {
    case inspect
    case buildRoad
    case zoneResidential
    case zoneCommercial
    case zoneOffice
    case bulldoze

    var zoneType: ZoneType? {
        switch self {
        case .buildRoad:        .road
        case .zoneResidential:  .residential
        case .zoneCommercial:   .commercial
        case .zoneOffice:       .office
        default:                nil
        }
    }
}

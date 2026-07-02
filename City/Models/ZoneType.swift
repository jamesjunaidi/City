import SwiftUI

enum ZoneType: Codable, Equatable, Hashable, CaseIterable, Sendable {
    case empty, road, residential, commercial, office, bulldoze

    var displayName: String {
        switch self {
        case .empty:       "Empty"
        case .road:        "Road"
        case .residential: "Residential"
        case .commercial:  "Commercial"
        case .office:      "Office"
        case .bulldoze:    "Bulldoze"
        }
    }

    var icon: String {
        switch self {
        case .empty:       "square.dashed"
        case .road:        "road.lanes"
        case .residential: "house.fill"
        case .commercial:  "storefront.fill"
        case .office:      "building.columns.fill"
        case .bulldoze:    "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .empty:       .gray
        case .road:        Color(white: 0.4)
        case .residential: .green
        case .commercial:  .blue
        case .office:      .purple
        case .bulldoze:    .red
        }
    }

    var buildCost: Double {
        switch self {
        case .empty:       0
        case .road:        20
        case .residential: 0
        case .commercial:  0
        case .office:      0
        case .bulldoze:    0
        }
    }
}

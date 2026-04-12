import SwiftUI

enum ZoneType: Codable, Equatable, Hashable, CaseIterable, Sendable {
    case empty, road, residential, commercial, industrial

    var displayName: String {
        switch self {
        case .empty:       "Empty"
        case .road:        "Road"
        case .residential: "Residential"
        case .commercial:  "Commercial"
        case .industrial:  "Industrial"
        }
    }

    var icon: String {
        switch self {
        case .empty:       "square.dashed"
        case .road:        "road.lanes"
        case .residential: "house.fill"
        case .commercial:  "storefront.fill"
        case .industrial:  "building.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .empty:       .gray
        case .road:        Color(white: 0.4)
        case .residential: .green
        case .commercial:  .blue
        case .industrial:  .orange
        }
    }

    var buildCost: Double {
        switch self {
        case .empty:       0
        case .road:        100
        case .residential: 500
        case .commercial:  750
        case .industrial:  600
        }
    }
}

import SwiftUI

private let kBuildableZones: [ZoneType] = [.road, .residential, .commercial, .industrial]

struct HUDView: View {
    let treasury: Double
    let population: Int
    let day: Int
    @Binding var selectedZone: ZoneType

    var body: some View {
        VStack(spacing: 0) {
            StatsBar(treasury: treasury, population: population, day: day)
            Spacer()
            BuildToolbar(selectedZone: $selectedZone)
        }
    }
}

// MARK: - Stats bar

private struct StatsBar: View {
    let treasury: Double
    let population: Int
    let day: Int

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: treasury.formatted(.number.precision(.fractionLength(0))),
                     icon: "dollarsign.circle.fill",
                     tint: .yellow)

            Spacer()

            StatPill(value: "\(population)",
                     icon: "person.2.fill",
                     tint: .cyan)

            Spacer()

            StatPill(value: "Day \(day)",
                     icon: "calendar",
                     tint: Color(white: 0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

private struct StatPill: View {
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 15, weight: .semibold))
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Build toolbar

private struct BuildToolbar: View {
    @Binding var selectedZone: ZoneType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(kBuildableZones, id: \.self) { zone in
                    ZoneCard(zone: zone, isSelected: selectedZone == zone) {
                        let next: ZoneType = selectedZone == zone ? .empty : zone
                        selectedZone = next
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

                DividerLine()

                BulldozeCard(isSelected: selectedZone == .empty && false) // placeholder hook
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

// MARK: - Zone card

private struct ZoneCard: View {
    let zone: ZoneType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected
                              ? zone.color.opacity(0.25)
                              : Color.white.opacity(0.07))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? zone.color : Color.white.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1)
                        )

                    Image(systemName: zone.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isSelected ? zone.color : Color.white.opacity(0.65))
                        .symbolEffect(.bounce, value: isSelected)
                }

                // Label
                VStack(spacing: 2) {
                    Text(zone.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? zone.color : Color.white.opacity(0.75))

                    Text("$\(Int(zone.buildCost))")
                        .font(.system(size: 10, weight: .regular).monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .buttonStyle(.plain)
    }
}

// MARK: - Bulldoze card

private struct BulldozeCard: View {
    let isSelected: Bool

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(isSelected ? 0.25 : 0.07))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? Color.red : Color.white.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1)
                        )

                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.red.opacity(isSelected ? 1 : 0.5))
                }

                VStack(spacing: 2) {
                    Text("Bulldoze")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(isSelected ? 1 : 0.5))
                    Text("free")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Divider

private struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 60)
    }
}

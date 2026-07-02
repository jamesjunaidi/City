import SwiftUI

private let kBuildableModes: [InputMode] = [.buildRoad, .zoneResidential, .zoneCommercial, .zoneOffice]

struct HUDView: View {
    let playerFunds: Int
    let population: Int
    @Binding var inputMode: InputMode

    var body: some View {
        VStack(spacing: 0) {
            StatsBar(playerFunds: playerFunds, population: population)
            Spacer()
            BuildToolbar(inputMode: $inputMode)
        }
    }
}

// MARK: - Stats bar

private struct StatsBar: View {
    let playerFunds: Int
    let population: Int

    var body: some View {
        HStack(spacing: 0) {
            StatPill(value: "\(playerFunds)",
                     icon: "dollarsign.circle.fill",
                     tint: .yellow)

            Spacer()

            StatPill(value: "\(population)",
                     icon: "person.2.fill",
                     tint: .cyan)
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
                .foregroundStyle(.black)
        }
    }
}

// MARK: - Build toolbar

private struct BuildToolbar: View {
    @Binding var inputMode: InputMode

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(kBuildableModes, id: \.self) { mode in
                    ZoneCard(mode: mode, isSelected: inputMode == mode) {
                        let next: InputMode = inputMode == mode ? .inspect : mode
                        inputMode = next
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }

                DividerLine()

                BulldozeCard(isSelected: inputMode == .bulldoze) {
                    let next: InputMode = inputMode == .bulldoze ? .inspect : .bulldoze
                    inputMode = next
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
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
    let mode: InputMode
    let isSelected: Bool
    let action: () -> Void

    private var zoneType: ZoneType { mode.zoneType ?? .road }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon tile
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected
                              ? zoneType.color.opacity(0.25)
                              : Color.white.opacity(0.07))
                        .frame(width: 64, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isSelected ? zoneType.color : Color.white.opacity(0.12),
                                        lineWidth: isSelected ? 2 : 1)
                        )

                    Image(systemName: zoneType.icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(isSelected ? zoneType.color : Color.white.opacity(0.65))
                        .symbolEffect(.bounce, value: isSelected)
                }

                // Label
                VStack(spacing: 2) {
                    Text(zoneType.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? zoneType.color : Color.white.opacity(0.75))

                    Text("$\(Int(zoneType.buildCost))")
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

import SwiftUI

struct HUDView: View {
    let treasury: Double
    let population: Int
    let day: Int
    @Binding var selectedZone: ZoneType

    private let buildableZones: [ZoneType] = [.road, .residential, .commercial, .industrial]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            bottomToolbar
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 20) {
            Label(treasury.formatted(.number.precision(.fractionLength(0))), systemImage: "dollarsign.circle.fill")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.yellow)

            Label("\(population)", systemImage: "person.2.fill")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)

            Spacer()

            Text("Day \(day)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Bottom toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            ForEach(buildableZones, id: \.self) { zone in
                toolbarButton(for: zone)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func toolbarButton(for zone: ZoneType) -> some View {
        let isSelected = selectedZone == zone
        return Button {
            selectedZone = isSelected ? .empty : zone
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: zone.icon)
                    .font(.title2)
                Text(zone.displayName)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? zone.color : .white)
            .frame(width: 68, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? zone.color.opacity(0.25) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? zone.color : Color.clear, lineWidth: 1.5)
                    )
            )
        }
    }
}

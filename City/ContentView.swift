import SwiftUI

struct ContentView: View {
    @State private var grid = CityGrid()
    @State private var engine = CitySimulationEngine()
    @State private var selectedZone: ZoneType = .empty

    var body: some View {
        ZStack {
            CityRealityView(
                grid: grid,
                selectedZone: $selectedZone,
                engine: engine
            )
            .ignoresSafeArea()

            HUDView(
                treasury:     engine.treasury,
                population:   engine.population,
                day:          engine.day,
                selectedZone: $selectedZone
            )
        }
    }
}

#Preview {
    ContentView()
}

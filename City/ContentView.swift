import SwiftUI

struct ContentView: View {
    @State private var grid = CityGrid()
    @State private var engine = CitySimulationEngine()
    @State private var selectedZone: ZoneType = .empty

    // Simulation state surfaced to the HUD.
    @State private var treasury: Double = 10_000
    @State private var population: Int = 0
    @State private var day: Int = 0

    var body: some View {
        ZStack {
            CityRealityView(
                grid: grid,
                selectedZone: $selectedZone,
                engine: engine,
                onSimulationResult: { result in
                    treasury  = result.treasury
                    population = result.population
                    day        = result.day
                }
            )
            .ignoresSafeArea()

            HUDView(
                treasury:     treasury,
                population:   population,
                day:          day,
                selectedZone: $selectedZone
            )
        }
    }
}

#Preview {
    ContentView()
}

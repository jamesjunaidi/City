import SwiftUI

struct ContentView: View {
    @State private var grid = CityGrid()
    @State private var engine = CitySimulationEngine()
    @State private var inputMode: InputMode = .inspect

    var body: some View {
        ZStack {
            CityRealityView(
                grid: grid,
                inputMode: $inputMode,
                engine: engine
            )
            .ignoresSafeArea()

            HUDView(
                playerFunds:  engine.playerFunds,
                population:   engine.population,
                inputMode: $inputMode
            )
        }
    }
}

#Preview {
    ContentView()
}

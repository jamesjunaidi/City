import SwiftUI

struct ContentView: View {
    @State private var scene: CityScene
    @State private var grid: CityGrid
    @State private var engine: CitySimulationEngine
    @State private var inputMode: InputMode = .inspect
    @State private var playerFunds: Int = 20000
    @State private var population: Int = 0

    init() {
        let g = CityGrid()
        let e = CitySimulationEngine()
        let s = CityScene(size: CGSize(width: 400, height: 800))
        _grid = State(initialValue: g)
        _engine = State(initialValue: e)
        _scene = State(initialValue: s)
    }

    var body: some View {
        ZStack {
            CitySpriteView(inputMode: $inputMode, scene: scene)
                .ignoresSafeArea()

            HUDView(
                playerFunds: playerFunds,
                population:  population,
                inputMode: $inputMode
            )
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                let result = engine.tick(grid: grid)
                scene.applyUpgrades(result.upgrades)
                playerFunds = engine.playerFunds
                population  = engine.population
            }
        }
    }
}

#Preview {
    ContentView()
}

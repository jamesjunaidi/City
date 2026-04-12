import SwiftUI
import RealityKit

@main
struct CityApp: App {
    init() {
        // RealityKit requires custom Components to be registered before use.
        BuildingComponent.registerComponent()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

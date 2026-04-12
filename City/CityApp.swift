import SwiftUI
import RealityKit

@main
struct CityApp: App {
    init() {
        // RealityKit requires custom Components to be registered before use.
        BuildingComponent.registerComponent()
    }

    // Qualify explicitly — both SwiftUI and RealityKit export a type named `Scene`.
    var body: some SwiftUI.Scene {
        WindowGroup {
            ContentView()
        }
    }
}

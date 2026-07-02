import SwiftUI
import SpriteKit

struct CitySpriteView: UIViewRepresentable {
    @Binding var inputMode: InputMode
    let scene: CityScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.isMultipleTouchEnabled = false
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        scene.inputMode = inputMode
        if scene.size != uiView.bounds.size {
            scene.size = uiView.bounds.size
        }
    }
}

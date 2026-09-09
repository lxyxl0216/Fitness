import SwiftUI
import SceneKit

struct MuscleAtlasView: View {
    @Binding var selectedMuscle: String
    @Environment(\.dismiss) private var dismiss
    @State private var selection: String

    init(selectedMuscle: Binding<String>) {
        _selectedMuscle = selectedMuscle
        _selection = State(initialValue: ExerciseCatalog.muscles.contains(selectedMuscle.wrappedValue) ? selectedMuscle.wrappedValue : "胸部")
    }

    var body: some View {
        ScreenContent {
            VStack(alignment: .leading, spacing: 6) {
                Text("选择训练部位").font(.largeTitle.bold())
                Text("拖动旋转，双指缩放，直接点击人体肌群。").font(.subheadline).foregroundStyle(Palette.muted)
            }
            Surface {
                MuscleSceneView(selection: $selection)
                    .frame(height: 430)
                    .accessibilityIdentifier("muscleModel")
                HStack {
                    Label(selection, systemImage: "scope").font(.headline).foregroundStyle(Palette.accent)
                    Spacer()
                    Text("3D 训练肌群示意").font(.caption).foregroundStyle(Palette.muted)
                }.padding(.top, 8)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExerciseCatalog.muscles, id: \.self) { muscle in
                        Button { selection = muscle } label: {
                            Text(muscle).font(.subheadline.weight(.medium)).padding(.horizontal, 16).frame(minHeight: 44)
                                .foregroundStyle(selection == muscle ? Color.white : Palette.muted)
                                .background(selection == muscle ? Palette.button : Palette.surface, in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("muscle-\(muscle)")
                    }
                }
            }
            Button("查看\(selection)动作") {
                selectedMuscle = selection
                dismiss()
            }.buttonStyle(PrimaryButton()).accessibilityIdentifier("applyMuscleFilter")
            Text("模型用于训练部位导航，不作为医学解剖或诊断依据。正面可选胸部、肩部、手臂、核心和腿部；旋转至背面可点选背部。")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .navigationTitle("3D 人体").navigationBarTitleDisplayMode(.inline)
    }
}

private struct MuscleSceneView: UIViewRepresentable {
    @Binding var selection: String

    func makeCoordinator() -> Coordinator { Coordinator(selection: $selection) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = HumanScene.make()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.didTap(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        context.coordinator.view = view
        context.coordinator.updateHighlight()
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.updateHighlight()
    }

    final class Coordinator: NSObject {
        var selection: Binding<String>
        weak var view: SCNView?

        init(selection: Binding<String>) { self.selection = selection }

        @objc func didTap(_ recognizer: UITapGestureRecognizer) {
            guard let view else { return }
            let options: [SCNHitTestOption: Any] = [.categoryBitMask: 2, .firstFoundOnly: true]
            guard let node = view.hitTest(recognizer.location(in: view), options: options).first?.node,
                  let muscle = node.name else { return }
            selection.wrappedValue = muscle
            updateHighlight()
        }

        func updateHighlight() {
            guard let scene = view?.scene else { return }
            scene.rootNode.enumerateChildNodes { node, _ in
                guard node.categoryBitMask == 2, let muscle = node.name else { return }
                node.geometry?.firstMaterial?.diffuse.contents = muscle == self.selection.wrappedValue
                    ? UIColor(red: 0.05, green: 0.72, blue: 0.49, alpha: 1)
                    : HumanScene.color(for: muscle)
                node.geometry?.firstMaterial?.emission.contents = muscle == self.selection.wrappedValue
                    ? UIColor(red: 0.01, green: 0.18, blue: 0.11, alpha: 1)
                    : UIColor.black
            }
        }
    }
}

private enum HumanScene {
    static func make() -> SCNScene {
        let scene = SCNScene()
        let root = scene.rootNode

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 39
        camera.position = SCNVector3(0, 1.25, 10.2)
        camera.look(at: SCNVector3(0, 1.15, 0))
        root.addChildNode(camera)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .area
        key.light?.intensity = 950
        key.light?.color = UIColor.white
        key.position = SCNVector3(-4, 6, 6)
        root.addChildNode(key)
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 420
        fill.light?.color = UIColor(red: 0.55, green: 0.78, blue: 0.68, alpha: 1)
        fill.position = SCNVector3(4, 2, 4)
        root.addChildNode(fill)
        let back = SCNNode()
        back.light = SCNLight()
        back.light?.type = .omni
        back.light?.intensity = 520
        back.position = SCNVector3(0, 3, -5)
        root.addChildNode(back)
        scene.lightingEnvironment.intensity = 0.25

        addSphere(root, radius: 0.48, position: SCNVector3(0, 4.05, 0), scale: SCNVector3(0.82, 1.05, 0.82), neutral: true)
        addCapsule(root, radius: 0.22, height: 0.55, position: SCNVector3(0, 3.42, 0), muscle: nil)
        addSphere(root, radius: 0.72, position: SCNVector3(-0.4, 2.85, 0.17), scale: SCNVector3(0.88, 0.7, 0.48), muscle: "胸部")
        addSphere(root, radius: 0.72, position: SCNVector3(0.4, 2.85, 0.17), scale: SCNVector3(0.88, 0.7, 0.48), muscle: "胸部")
        addCapsule(root, radius: 0.48, height: 1.65, position: SCNVector3(0, 2.15, 0.0), scale: SCNVector3(1.35, 1, 0.72), muscle: "核心")
        addCapsule(root, radius: 0.52, height: 1.75, position: SCNVector3(0, 2.35, -0.34), scale: SCNVector3(1.45, 1, 0.4), muscle: "背部")
        addSphere(root, radius: 0.45, position: SCNVector3(-1.0, 2.92, 0), scale: SCNVector3(1, 0.9, 0.9), muscle: "肩部")
        addSphere(root, radius: 0.45, position: SCNVector3(1.0, 2.92, 0), scale: SCNVector3(1, 0.9, 0.9), muscle: "肩部")

        addCapsule(root, radius: 0.27, height: 1.35, position: SCNVector3(-1.12, 2.08, 0), eulerZ: -0.08, muscle: "手臂")
        addCapsule(root, radius: 0.27, height: 1.35, position: SCNVector3(1.12, 2.08, 0), eulerZ: 0.08, muscle: "手臂")
        addCapsule(root, radius: 0.22, height: 1.28, position: SCNVector3(-1.22, 0.95, 0), eulerZ: -0.1, muscle: "手臂")
        addCapsule(root, radius: 0.22, height: 1.28, position: SCNVector3(1.22, 0.95, 0), eulerZ: 0.1, muscle: "手臂")
        addSphere(root, radius: 0.25, position: SCNVector3(-1.3, 0.2, 0), scale: SCNVector3(0.75, 1.15, 0.62), neutral: true)
        addSphere(root, radius: 0.25, position: SCNVector3(1.3, 0.2, 0), scale: SCNVector3(0.75, 1.15, 0.62), neutral: true)

        addSphere(root, radius: 0.62, position: SCNVector3(0, 1.15, 0), scale: SCNVector3(1.15, 0.72, 0.7), muscle: "腿部")
        addCapsule(root, radius: 0.39, height: 1.8, position: SCNVector3(-0.43, 0.08, 0), eulerZ: 0.035, muscle: "腿部")
        addCapsule(root, radius: 0.39, height: 1.8, position: SCNVector3(0.43, 0.08, 0), eulerZ: -0.035, muscle: "腿部")
        addCapsule(root, radius: 0.29, height: 1.75, position: SCNVector3(-0.43, -1.45, 0), eulerZ: -0.02, muscle: "腿部")
        addCapsule(root, radius: 0.29, height: 1.75, position: SCNVector3(0.43, -1.45, 0), eulerZ: 0.02, muscle: "腿部")
        addSphere(root, radius: 0.34, position: SCNVector3(-0.43, -2.36, 0.14), scale: SCNVector3(0.75, 0.35, 1.45), neutral: true)
        addSphere(root, radius: 0.34, position: SCNVector3(0.43, -2.36, 0.14), scale: SCNVector3(0.75, 0.35, 1.45), neutral: true)

        let floor = SCNNode(geometry: SCNCylinder(radius: 2.1, height: 0.05))
        floor.position = SCNVector3(0, -2.62, 0)
        floor.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.45, alpha: 0.12)
        root.addChildNode(floor)
        return scene
    }

    static func color(for muscle: String) -> UIColor {
        switch muscle {
        case "胸部": return UIColor(red: 0.80, green: 0.30, blue: 0.25, alpha: 1)
        case "背部": return UIColor(red: 0.55, green: 0.20, blue: 0.18, alpha: 1)
        case "肩部": return UIColor(red: 0.92, green: 0.43, blue: 0.25, alpha: 1)
        case "手臂": return UIColor(red: 0.70, green: 0.29, blue: 0.31, alpha: 1)
        case "核心": return UIColor(red: 0.86, green: 0.49, blue: 0.28, alpha: 1)
        default: return UIColor(red: 0.62, green: 0.24, blue: 0.25, alpha: 1)
        }
    }

    private static func addSphere(_ parent: SCNNode, radius: CGFloat, position: SCNVector3,
                                  scale: SCNVector3 = SCNVector3(1, 1, 1), muscle: String? = nil, neutral: Bool = false) {
        let node = SCNNode(geometry: SCNSphere(radius: radius))
        node.geometry?.firstMaterial = material(muscle: muscle, neutral: neutral)
        node.position = position
        node.scale = scale
        configure(node, muscle: muscle)
        parent.addChildNode(node)
    }

    private static func addCapsule(_ parent: SCNNode, radius: CGFloat, height: CGFloat, position: SCNVector3,
                                   scale: SCNVector3 = SCNVector3(1, 1, 1), eulerZ: Float = 0, muscle: String?) {
        let node = SCNNode(geometry: SCNCapsule(capRadius: radius, height: height))
        node.geometry?.firstMaterial = material(muscle: muscle, neutral: muscle == nil)
        node.position = position
        node.scale = scale
        node.eulerAngles.z = eulerZ
        configure(node, muscle: muscle)
        parent.addChildNode(node)
    }

    private static func configure(_ node: SCNNode, muscle: String?) {
        node.name = muscle
        node.categoryBitMask = muscle == nil ? 1 : 2
        node.geometry?.firstMaterial?.lightingModel = .physicallyBased
        node.geometry?.firstMaterial?.roughness.contents = 0.68
        node.geometry?.firstMaterial?.metalness.contents = 0.02
    }

    private static func material(muscle: String?, neutral: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.diffuse.contents = neutral ? UIColor(red: 0.76, green: 0.65, blue: 0.58, alpha: 1) : color(for: muscle ?? "")
        return material
    }
}

import SpriteKit
import UIKit

/// Routes touches and hardware keys to the player's fighter for both 1v1 and stage scenes.
/// Each finger owns the control it pressed, so lifting one finger never releases a button another finger still holds.
final class PlayerInputRouter {
    let controls = TouchControls()
    weak var fighter: Fighter?
    /// While paused only the pause control responds.
    var isPaused = false
    /// Once a round or stage is decided only the hitbox overlay can still be toggled.
    var actionsLocked = false
    var onTogglePause: (() -> Void)?
    var onToggleDebug: (() -> Void)?
    private var touchMap: [ObjectIdentifier: Control] = [:]
    private var keyMap: Set<Control> = []

    func touchesBegan(_ touches: Set<UITouch>, in scene: SKScene) {
        for touch in touches {
            if let control = controls.control(at: touch.location(in: scene)) { press(control, touch: ObjectIdentifier(touch)) }
        }
    }
    func touchesMoved(_ touches: Set<UITouch>, in scene: SKScene) {
        for touch in touches {
            let id = ObjectIdentifier(touch), next = controls.control(at: touch.location(in: scene))
            if touchMap[id] != next {
                release(touch: id)
                if let next { press(next, touch: id) }
            }
        }
    }
    func touchesEnded(_ touches: Set<UITouch>) {
        for touch in touches { release(touch: ObjectIdentifier(touch)) }
    }
    /// One finger pressing a control; tests pass synthetic identifiers.
    func press(_ control: Control, touch id: ObjectIdentifier) {
        touchMap[id] = control; controlDown(control)
    }
    func release(touch id: ObjectIdentifier) {
        if let old = touchMap.removeValue(forKey: id) { controlUp(old) }
    }
    func keyChanged(_ key: String, down: Bool) {
        guard let control = KeyboardInput.control(for: key) else { return }
        if down { if keyMap.insert(control).inserted { controlDown(control) } }
        else { keyMap.remove(control); controlUp(control) }
    }
    /// Pausing drops every held gameplay input but keeps the pause control's own press.
    func suspend() {
        touchMap = touchMap.filter { $0.value == .pause }
        keyMap = keyMap.intersection([.pause])
        controls.clearPressed(except: [.pause])
        fighter?.leftHeld = false; fighter?.rightHeld = false; fighter?.blockHeld = false
    }
    /// The app lost focus: forget every press, including pause.
    func reset() {
        touchMap.removeAll(); keyMap.removeAll(); controls.clearPressed()
    }
    /// Copies held directions and guard onto the fighter; scenes call this every fixed step.
    func applyHeld() {
        guard !isPaused, let fighter else { return }
        let held = Set(touchMap.values).union(keyMap)
        fighter.leftHeld = held.contains(.left)
        fighter.rightHeld = held.contains(.right)
        fighter.blockHeld = held.contains(.block) || held.contains(.down)
    }
    private func controlDown(_ control: Control) {
        if control == .pause { controls.setPressed(control, true); onTogglePause?(); return }
        guard !isPaused else { return }
        controls.setPressed(control, true)
        guard !actionsLocked || control == .debug else { return }
        switch control {
        case .up: fighter?.jump()
        case .attack: fighter?.attack()
        case .skill1: _ = fighter?.use("skill1")
        case .skill2: _ = fighter?.use("skill2")
        case .skill3: _ = fighter?.use("skill3")
        case .ult: _ = fighter?.use("ult")
        case .debug: onToggleDebug?()
        default: break
        }
        applyHeld()
    }
    private func controlUp(_ control: Control) {
        let stillHeld = touchMap.values.contains(control) || keyMap.contains(control)
        controls.setPressed(control, stillHeld); applyHeld()
    }
}

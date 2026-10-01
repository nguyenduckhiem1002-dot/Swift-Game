import SpriteKit

enum AIState { case approach, combo, retreat, defending, skill }

final class AIController {
    private let fighter: Fighter
    private let target: Fighter
    private let difficulty: Difficulty
    private(set) var state: AIState = .approach
    private var decisionClock: CGFloat = 0
    private var stateClock: CGFloat = 0
    init(fighter: Fighter, target: Fighter, difficulty: Difficulty) {
        self.fighter = fighter; self.target = target; self.difficulty = difficulty
    }
    func updateFixed(_ dt: CGFloat) {
        decisionClock -= dt; stateClock -= dt
        guard fighter.hp > 0, target.hp > 0 else { fighter.leftHeld = false; fighter.rightHeld = false; fighter.blockHeld = false; return }
        let delta = target.position.x - fighter.position.x
        let distance = abs(delta)
        if stateClock <= 0 { state = .approach; stateClock = 0.5 }
        fighter.leftHeld = false; fighter.rightHeld = false; fighter.blockHeld = false
        guard decisionClock <= 0 else { movement(delta: delta, distance: distance); return }
        decisionClock = difficulty.reaction
        if fighter.energy == 100 && distance >= 65 && distance <= 190, fighter.use("ult") { state = .skill; stateClock = 0.9; return }
        // SK3 buffs are worth casting from range or when hurt, once awakening tier I unlocks them.
        if fighter.awakeningTier >= 1, distance > 90 || fighter.hp < 50, CGFloat.random(in: 0...1) < difficulty.skillChance * 0.5,
           fighter.use("skill3") { state = .skill; stateClock = 0.5; return }
        if distance < 55 {
            if Int.random(in: 0..<100) < 25 { state = .defending; stateClock = 0.25 }
            else { state = .combo; fighter.attack(); stateClock = 0.6 }
        } else if distance < 180 && CGFloat.random(in: 0...1) < difficulty.skillChance {
            if fighter.energy >= 35 && distance < 90, fighter.use("skill2") { state = .skill; stateClock = 0.5 }
            else if fighter.use("skill1") { state = .skill; stateClock = 0.55 }
        } else if distance < 75 { state = .retreat; stateClock = 0.3 }
        movement(delta: delta, distance: distance)
    }
    private func movement(delta: CGFloat, distance: CGFloat) {
        guard !fighter.state.locksMovement else { return }
        if state == .defending { fighter.blockHeld = true }
        else if state == .retreat { fighter.leftHeld = delta > 0; fighter.rightHeld = delta < 0 }
        else if state == .approach && distance > 46 { fighter.leftHeld = delta < 0; fighter.rightHeld = delta > 0 }
        else if state == .combo && distance < 60 && fighter.currentMove == nil { fighter.attack() }
    }
}

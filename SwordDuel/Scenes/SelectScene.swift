import SpriteKit

final class SelectScene: GameScene {
    private var choice = 0
    private var difficulty: Difficulty = .normal
    private var cards: [SKSpriteNode] = []
    private var difficultyButtons: [MenuButton] = []
    override func didMove(to view: SKView) {
        let arena = ArenaBackground(); arena.zPosition = -10; arena.alpha = 0.62; addChild(arena)
        let heading = Theme.label("CHOOSE YOUR SWORDSMAN", size: 14, color: Theme.gold)
        heading.position = CGPoint(x: 240, y: 237); addChild(heading)
        for index in 0..<2 {
            let data = CharacterLibrary.all[index]
            let x: CGFloat = index == 0 ? 145 : 335
            let card = UIAssets.shared.sprite("portrait_frame", size: CGSize(width: 32, height: 32))
            card.centerRect = CGRect(x: 0.4375, y: 0.4375, width: 0.125, height: 0.125)
            card.size = CGSize(width: 144, height: 135)
            let panel = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.95), size: CGSize(width: 132, height: 123))
            panel.zPosition = -1; card.addChild(panel)
            card.name = "character\(index)"
            card.position = CGPoint(x: x, y: 150)
            card.color = Theme.gold
            card.colorBlendFactor = index == choice ? 0.25 : 0
            addChild(card); cards.append(card)
            let sprite = SKSpriteNode()
            SpriteSheet.shared.applyFrame(to: sprite, character: data, animation: "idle", index: 0)
            sprite.setScale(1.2)
            sprite.position = CGPoint(x: 0, y: -28)
            card.addChild(sprite)
            let label = Theme.label(data.name, size: 9, color: index == 0 ? Theme.ice : Theme.fire)
            label.position.y = -43; card.addChild(label)
            let sub = Theme.label(index == 0 ? "FROST" : "FLAME", size: 7)
            sub.position.y = -56; card.addChild(sub)
        }
        let caption = Theme.label("DIFFICULTY", size: 6, color: Theme.ice)
        caption.position = CGPoint(x: 150, y: 65); addChild(caption)
        for (index, level) in [Difficulty.easy, .normal].enumerated() {
            let button = MenuButton(text: level.rawValue.uppercased(), size: CGSize(width: 64, height: 24), difficulty: true) { [weak self] in
                self?.difficulty = level
                self?.refreshDifficulty()
            }
            button.position = CGPoint(x: 114 + CGFloat(index) * 72, y: 41)
            addChild(button); difficultyButtons.append(button)
        }
        refreshDifficulty()
        addChild(Theme.button("FIGHT", at: CGPoint(x: 330, y: 44)) { [weak self] in
            guard let self else { return }
            self.transition(to: FightScene(size: self.size, config: MatchConfig(playerIndex: self.choice, difficulty: self.difficulty)))
        })
    }
    private func refreshDifficulty() {
        for (index, button) in difficultyButtons.enumerated() { button.isSelected = (index == 0) == (difficulty == .easy) }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if endMenuTouches(touches) { return }
        for touch in touches {
            let point = touch.location(in: self)
            for index in cards.indices where cards[index].contains(point) {
                choice = index
                for i in cards.indices { cards[i].colorBlendFactor = i == choice ? 0.25 : 0 }
                return
            }
        }
    }
}

import SpriteKit

final class SelectScene: GameScene {
    private var choice = 0
    private var mapIndex = 0
    private var difficulty: Difficulty = .normal
    private var cards: [SKSpriteNode] = []
    private var difficultyButtons: [MenuButton] = []
    private var arena: ArenaBackground?
    private let detailName = Theme.label("", size: 9)
    private let detailRole = Theme.label("", size: 6, color: .lightGray)
    private let mapName = Theme.label("", size: 7, color: Theme.gold)
    private let mapSummary = Theme.label("", size: 5, color: Theme.ice)
    override func didMove(to view: SKView) {
        let heading = Theme.label("CHOOSE YOUR SWORDSMAN", size: 12, color: Theme.gold)
        heading.position = CGPoint(x: 240, y: 254); addChild(heading)
        // Five cards on the first row and four on the second fit the full nine-fighter roster at 480×270.
        for (index, data) in CharacterLibrary.all.enumerated() {
            let row = index / 5, column = index % 5
            let rowCount = min(5, CharacterLibrary.all.count - row * 5)
            let x = 240 + (CGFloat(column) - CGFloat(rowCount - 1) / 2) * 80
            let card = UIAssets.shared.sprite("portrait_frame", size: CGSize(width: 32, height: 32))
            card.centerRect = CGRect(x: 0.4375, y: 0.4375, width: 0.125, height: 0.125)
            card.size = CGSize(width: 72, height: 64)
            let panel = SKSpriteNode(color: Theme.navy.withAlphaComponent(0.95), size: CGSize(width: 64, height: 56))
            panel.zPosition = -1; card.addChild(panel)
            card.name = "character\(index)"
            card.position = CGPoint(x: x, y: 204 - CGFloat(row) * 70)
            card.color = Theme.gold
            addChild(card); cards.append(card)
            let sprite = SKSpriteNode()
            SpriteSheet.shared.applyFrame(to: sprite, character: data, animation: "idle", index: 0)
            sprite.setScale(44 / data.spriteSize)
            sprite.position = CGPoint(x: 0, y: -21)
            card.addChild(sprite)
            let sub = Theme.label(data.id.uppercased(), size: 5, color: data.accentColor)
            sub.position.y = -26; sub.zPosition = 1; card.addChild(sub)
        }
        detailName.position = CGPoint(x: 240, y: 82); addChild(detailName)
        detailRole.position = CGPoint(x: 240, y: 70); addChild(detailRole)

        let caption = Theme.label("DIFFICULTY", size: 6, color: Theme.ice)
        caption.position = CGPoint(x: 80, y: 54); addChild(caption)
        for (index, level) in [Difficulty.easy, .normal].enumerated() {
            let button = MenuButton(text: level.rawValue.uppercased(), size: CGSize(width: 64, height: 24), difficulty: true) { [weak self] in
                self?.difficulty = level
                self?.refreshDifficulty()
            }
            button.position = CGPoint(x: 46 + CGFloat(index) * 68, y: 34)
            addChild(button); difficultyButtons.append(button)
        }
        refreshDifficulty()

        let mapCaption = Theme.label("MAP", size: 6, color: Theme.ice)
        mapCaption.position = CGPoint(x: 240, y: 54); addChild(mapCaption)
        mapName.position = CGPoint(x: 240, y: 34); addChild(mapName)
        mapSummary.position = CGPoint(x: 240, y: 12); addChild(mapSummary)
        for (offset, text, x) in [(-1, "<", CGFloat(166)), (1, ">", CGFloat(314))] {
            let button = MenuButton(text: text, size: CGSize(width: 24, height: 24)) { [weak self] in self?.cycleMap(offset) }
            button.position = CGPoint(x: x, y: 34); addChild(button)
        }

        addChild(Theme.button("FIGHT", at: CGPoint(x: 410, y: 34), width: 90) { [weak self] in
            guard let self else { return }
            // The CPU picks a different fighter each match; rematches keep the same pairing.
            let others = CharacterLibrary.all.indices.filter { $0 != self.choice }
            let config = MatchConfig(playerIndex: self.choice, opponentIndex: others.randomElement() ?? self.choice,
                                     difficulty: self.difficulty, mapID: MapLibrary.all[self.mapIndex].id)
            self.transition(to: FightScene(size: self.size, config: config))
        })
        refreshSelection()
        refreshMap()
    }
    private func refreshDifficulty() {
        for (index, button) in difficultyButtons.enumerated() { button.isSelected = (index == 0) == (difficulty == .easy) }
    }
    private func refreshSelection() {
        for i in cards.indices { cards[i].colorBlendFactor = i == choice ? 0.25 : 0 }
        let data = CharacterLibrary.all[choice]
        detailName.text = data.name; detailName.fontColor = data.accentColor
        detailRole.text = (data.role ?? "").uppercased()
    }
    private func cycleMap(_ offset: Int) {
        mapIndex = (mapIndex + offset + MapLibrary.all.count) % MapLibrary.all.count
        refreshMap()
    }
    private func refreshMap() {
        let map = MapLibrary.all[mapIndex]
        arena?.removeFromParent()
        let preview = ArenaBackground(map: map); preview.zPosition = -10; preview.alpha = 0.62
        addChild(preview); arena = preview
        mapName.text = map.name
        mapSummary.text = map.summary ?? ""
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if endMenuTouches(touches) { return }
        for touch in touches {
            let point = touch.location(in: self)
            for index in cards.indices where cards[index].contains(point) {
                choice = index
                refreshSelection()
                return
            }
        }
    }
}

import SpriteKit

final class ResultScene: GameScene {
    private let config: MatchConfig
    private let victory: Bool
    init(size: CGSize, config: MatchConfig, victory: Bool) { self.config = config; self.victory = victory; super.init(size: size) }
    required init?(coder: NSCoder) { fatalError() }
    override func didMove(to view: SKView) {
        let arena = ArenaBackground(); arena.zPosition = -10; arena.alpha = 0.62; addChild(arena)
        let title = Theme.label(victory ? "VICTORY" : "DEFEAT", size: 27, color: victory ? Theme.gold : Theme.fire)
        title.position = CGPoint(x: 240, y: 182); addChild(title)
        let detail = Theme.label(victory ? "THE SWORD SPIRIT PREVAILS" : "TRAIN AND RETURN", size: 9, color: .white)
        detail.position = CGPoint(x: 240, y: 147); addChild(detail)
        addChild(Theme.button("REMATCH", at: CGPoint(x: 240, y: 96)) { [weak self] in
            guard let self else { return }; self.transition(to: FightScene(size: self.size, config: self.config))
        })
        addChild(Theme.button("BACK TO MENU", at: CGPoint(x: 240, y: 55), width: 130) { [weak self] in
            self?.transition(to: TitleScene(size: CGSize(width: 480, height: 270)))
        })
    }
}

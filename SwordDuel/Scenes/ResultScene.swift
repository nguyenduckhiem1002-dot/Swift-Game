import SpriteKit

final class ResultScene: GameScene {
    private let victory: Bool
    private let detailText: String
    private let retryTitle: String
    /// Builds the scene that REMATCH / RETRY starts.
    private let retry: () -> SKScene
    init(size: CGSize, victory: Bool, detail: String, retryTitle: String = "REMATCH", retry: @escaping () -> SKScene) {
        self.victory = victory; detailText = detail; self.retryTitle = retryTitle; self.retry = retry
        super.init(size: size)
    }
    convenience init(size: CGSize, config: MatchConfig, victory: Bool) {
        self.init(size: size, victory: victory, detail: victory ? "THE SWORD SPIRIT PREVAILS" : "TRAIN AND RETURN") {
            FightScene(size: size, config: config)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func didMove(to view: SKView) {
        let arena = ArenaBackground(); arena.zPosition = -10; arena.alpha = 0.62; addChild(arena)
        let title = Theme.label(victory ? "VICTORY" : "DEFEAT", size: 27, color: victory ? Theme.gold : Theme.fire)
        title.position = CGPoint(x: 240, y: 182); addChild(title)
        let detail = Theme.label(detailText, size: 9, color: .white)
        detail.position = CGPoint(x: 240, y: 147); addChild(detail)
        addChild(Theme.button(retryTitle, at: CGPoint(x: 240, y: 96)) { [weak self] in
            guard let self else { return }; self.transition(to: self.retry())
        })
        addChild(Theme.button("BACK TO MENU", at: CGPoint(x: 240, y: 55), width: 130) { [weak self] in
            self?.transition(to: TitleScene(size: CGSize(width: 480, height: 270)))
        })
    }
}

import SpriteKit

final class TitleScene: GameScene {
    override func didMove(to view: SKView) {
        let arena = ArenaBackground(); arena.zPosition = -10; arena.alpha = 0.62; addChild(arena)
        let title = Theme.label("KIẾM TIÊN ĐỐI KHÁNG", size: 20, color: Theme.gold)
        title.position = CGPoint(x: 240, y: 186)
        addChild(title)
        let subtitle = Theme.label("PIXEL SWORD DUEL", size: 8, color: Theme.ice)
        subtitle.position = CGPoint(x: 240, y: 158)
        addChild(subtitle)
        addChild(Theme.button("START", at: CGPoint(x: 240, y: 116)) { [weak self] in
            self?.transition(to: SelectScene(size: CGSize(width: 480, height: 270)))
        })
        addChild(Theme.button("VƯỢT ẢI", at: CGPoint(x: 240, y: 82)) { [weak self] in
            let select = SelectScene(size: CGSize(width: 480, height: 270)); select.stageMode = true
            self?.transition(to: select)
        })
        addChild(Theme.button("QUIT", at: CGPoint(x: 240, y: 48)) { [weak self] in
            _ = self
            exit(0)
        })
        let hint = Theme.label("LANDSCAPE  •  TOUCH OR KEYBOARD", size: 6, color: .lightGray)
        hint.position = CGPoint(x: 240, y: 26); addChild(hint)
    }
}

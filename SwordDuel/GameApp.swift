import UIKit
import SpriteKit

@main
final class GameApp: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
}

final class GameSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
    func sceneWillResignActive(_ scene: UIScene) {
        guard let skView = window?.rootViewController?.view as? SKView else { return }
        (skView.scene as? KeyboardControllable)?.pauseForInterruption()
    }
}

final class GameViewController: UIViewController {
    private var gameView: SKView { view as! SKView }
    override func loadView() { view = SKView(frame: .zero) }
    override func viewDidLoad() {
        super.viewDidLoad()
        gameView.ignoresSiblingOrder = true
        gameView.isMultipleTouchEnabled = true
        gameView.preferredFramesPerSecond = 60
        let size = CGSize(width: 480, height: 270)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-select") {
            gameView.presentScene(SelectScene(size: size))
        } else if let index = arguments.firstIndex(of: "--preview-stage") {
            // `--preview-stage <stageId> [--character <id>]` jumps straight into stage mode.
            let id = index + 1 < arguments.count ? arguments[index + 1] : ""
            let stage = StageLibrary.all.first { $0.id == id } ?? StageLibrary.all[0]
            let character = arguments.firstIndex(of: "--character").flatMap { $0 + 1 < arguments.count ? CharacterLibrary.index(of: arguments[$0 + 1]) : nil } ?? 0
            gameView.presentScene(StageScene(size: size, stage: stage, playerIndex: character, difficulty: .normal))
        } else if arguments.contains("--preview-fight") || arguments.contains("--preview-ui-states") || arguments.contains("--test-ui") || arguments.contains("--preview-paused") {
            // `--character <id>`, `--opponent <id>` and `--map <id>` preview newly imported art.
            func value(after flag: String) -> String? {
                guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
                return arguments[index + 1]
            }
            let player = value(after: "--character").flatMap(CharacterLibrary.index(of:)) ?? (arguments.contains("--flame") ? 1 : 0)
            let opponent = value(after: "--opponent").flatMap(CharacterLibrary.index(of:)) ?? (player == 0 ? 1 : 0)
            let mapID = value(after: "--map") ?? MapLibrary.all[0].id
            gameView.presentScene(FightScene(size: size, config: MatchConfig(playerIndex: player, opponentIndex: opponent, difficulty: .easy, mapID: mapID)))
        } else {
            gameView.presentScene(TitleScene(size: size))
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); becomeFirstResponder() }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { (gameView.scene as? KeyboardControllable)?.keyChanged(key.charactersIgnoringModifiers.lowercased(), down: true) } }
        super.pressesBegan(presses, with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { (gameView.scene as? KeyboardControllable)?.keyChanged(key.charactersIgnoringModifiers.lowercased(), down: false) } }
        super.pressesEnded(presses, with: event)
    }
}

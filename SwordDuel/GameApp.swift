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
        (skView.scene as? FightScene)?.pauseForInterruption()
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
        } else if arguments.contains("--preview-fight") || arguments.contains("--preview-ui-states") || arguments.contains("--test-ui") || arguments.contains("--preview-paused") {
            gameView.presentScene(FightScene(size: size, config: MatchConfig(playerIndex: arguments.contains("--flame") ? 1 : 0, difficulty: .easy)))
        } else {
            gameView.presentScene(TitleScene(size: size))
        }
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var canBecomeFirstResponder: Bool { true }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); becomeFirstResponder() }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { (gameView.scene as? FightScene)?.keyChanged(key.charactersIgnoringModifiers.lowercased(), down: true) } }
        super.pressesBegan(presses, with: event)
    }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { if let key = press.key { (gameView.scene as? FightScene)?.keyChanged(key.charactersIgnoringModifiers.lowercased(), down: false) } }
        super.pressesEnded(presses, with: event)
    }
}

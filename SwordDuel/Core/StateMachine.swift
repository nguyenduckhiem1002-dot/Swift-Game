import Foundation

enum FighterState: Equatable {
    case idle, walk, jump, block, attacking(String), hurt, ko, win
    var locksMovement: Bool {
        switch self { case .attacking, .hurt, .ko, .win: return true; default: return false }
    }
}

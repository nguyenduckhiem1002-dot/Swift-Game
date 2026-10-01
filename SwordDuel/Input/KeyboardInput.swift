import Foundation

enum KeyboardInput {
    static func control(for key: String) -> Control? {
        switch key {
        case "a": return .left
        case "d": return .right
        case "w": return .up
        case "s": return .block
        case "j": return .attack
        case "k": return .skill1
        case "l": return .skill2
        case "u": return .skill3
        case "i": return .ult
        case "b": return .debug
        case "p": return .pause
        default: return nil
        }
    }
}

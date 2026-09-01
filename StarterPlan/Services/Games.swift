import SwiftUI

struct MiniGame: Identifiable, Hashable {
    let id: String
    let name: String
    let blurb: String
    let icon: String
    let cost: Int          // coins, 0 = free
    let tint: Color
}

enum GameCatalog {
    static let all: [MiniGame] = [
        MiniGame(id: "tap_rush", name: "Tap Rush", blurb: "Hit the dots before they fade.",
                 icon: "target", cost: 0, tint: Theme.accent),
        MiniGame(id: "snake", name: "Snake", blurb: "Swipe to eat, don't bite yourself.",
                 icon: "scribble.variable", cost: 150, tint: Theme.teal),
        MiniGame(id: "flappy", name: "Flap", blurb: "Tap to fly. Mind the gaps.",
                 icon: "bird.fill", cost: 400, tint: Theme.gold)
    ]

    static func game(_ id: String) -> MiniGame? { all.first { $0.id == id } }
}

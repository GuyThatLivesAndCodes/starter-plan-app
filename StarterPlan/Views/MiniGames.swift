import SwiftUI

/// Host for a mini-game played during rest. The game is force-quit the moment
/// rest hits zero — the workout always wins.
struct MiniGameHost: View {
    let game: MiniGame
    let locked: Bool
    let onExit: () -> Void

    @State private var score = 0

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(game.name, systemImage: game.icon)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(game.tint)
                Spacer()
                Text("\(score)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Button {
                    Feedback.shared.tap(); onExit()
                } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .black))
                        .foregroundStyle(Theme.textDim)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Theme.surfaceHigh))
                }
                .buttonStyle(.plain)
            }

            ZStack {
                switch game.id {
                case "snake":  SnakeGame(score: $score, paused: locked)
                case "flappy": FlapGame(score: $score, paused: locked)
                default:       TapRushGame(score: $score, paused: locked)
                }

                if locked {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.82))
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 26)).foregroundStyle(Theme.accent)
                            Text("Rest's over")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text("Game locked. Back to the bar.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(14)
        .card(Theme.surfaceHigh)
        .animation(.easeInOut(duration: 0.25), value: locked)
    }
}

// MARK: - Tap Rush

struct TapRushGame: View {
    @Binding var score: Int
    let paused: Bool

    @State private var targets: [Target] = []
    @State private var missed = 0
    private let tick = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    struct Target: Identifiable {
        let id = UUID()
        let x: Double
        let y: Double
        let born = Date()
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg
                ForEach(targets) { t in
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 42, height: 42)
                        .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 2))
                        .position(x: t.x * geo.size.width, y: t.y * geo.size.height)
                        .transition(.scale.combined(with: .opacity))
                        .onTapGesture {
                            guard !paused else { return }
                            Feedback.shared.setChecked()
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                targets.removeAll { $0.id == t.id }
                                score += 1
                            }
                        }
                }
                if targets.isEmpty && score == 0 {
                    Text("Tap the dots")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
            }
        }
        .onReceive(tick) { _ in
            guard !paused else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                targets.append(Target(x: .random(in: 0.12...0.88), y: .random(in: 0.12...0.88)))
                targets.removeAll { Date().timeIntervalSince($0.born) > 1.6 }
                if targets.count > 5 { targets.removeFirst() }
            }
        }
    }
}

// MARK: - Snake

struct SnakeGame: View {
    @Binding var score: Int
    let paused: Bool

    private let cols = 13
    private let rows = 13

    @State private var snake: [Cell] = [Cell(3, 6), Cell(2, 6), Cell(1, 6)]
    @State private var dir = Cell(1, 0)
    @State private var pending = Cell(1, 0)
    @State private var food = Cell(9, 6)
    @State private var dead = false
    private let tick = Timer.publish(every: 0.22, on: .main, in: .common).autoconnect()

    struct Cell: Equatable, Hashable {
        var x: Int, y: Int
        init(_ x: Int, _ y: Int) { self.x = x; self.y = y }
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) / CGFloat(cols)
            ZStack {
                Theme.bg
                ForEach(Array(snake.enumerated()), id: \.offset) { i, c in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i == 0 ? Theme.teal : Theme.teal.opacity(0.55))
                        .frame(width: size - 2, height: size - 2)
                        .position(pos(c, size, geo))
                }
                Circle()
                    .fill(Theme.gold)
                    .frame(width: size - 4, height: size - 4)
                    .position(pos(food, size, geo))

                if dead {
                    VStack(spacing: 6) {
                        Text("Ouch.").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(Theme.text)
                        Button("Again") { restart() }
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: 0x10221A))
                            .padding(.horizontal, 20).padding(.vertical, 9)
                            .background(Capsule().fill(Theme.accent))
                            .buttonStyle(.plain)
                    }
                    .padding(18)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 18).onEnded { v in
                guard !paused, !dead else { return }
                let h = v.translation.width, w = v.translation.height
                let next = abs(h) > abs(w) ? Cell(h > 0 ? 1 : -1, 0) : Cell(0, w > 0 ? 1 : -1)
                if next.x != -dir.x || next.y != -dir.y { pending = next }
            })
        }
        .onReceive(tick) { _ in step() }
    }

    private func pos(_ c: Cell, _ size: CGFloat, _ geo: GeometryProxy) -> CGPoint {
        let ox = (geo.size.width - size * CGFloat(cols)) / 2
        let oy = (geo.size.height - size * CGFloat(rows)) / 2
        return CGPoint(x: ox + (CGFloat(c.x) + 0.5) * size, y: oy + (CGFloat(c.y) + 0.5) * size)
    }

    private func step() {
        guard !paused, !dead else { return }
        dir = pending
        var head = snake[0]
        head.x = (head.x + dir.x + cols) % cols
        head.y = (head.y + dir.y + rows) % rows
        if snake.contains(head) {
            dead = true
            Feedback.shared.denied()
            return
        }
        snake.insert(head, at: 0)
        if head == food {
            score += 1
            Feedback.shared.setChecked()
            food = freeCell()
        } else {
            snake.removeLast()
        }
    }

    private func freeCell() -> Cell {
        var c = Cell(Int.random(in: 0..<cols), Int.random(in: 0..<rows))
        while snake.contains(c) { c = Cell(Int.random(in: 0..<cols), Int.random(in: 0..<rows)) }
        return c
    }

    private func restart() {
        snake = [Cell(3, 6), Cell(2, 6), Cell(1, 6)]
        dir = Cell(1, 0); pending = dir
        food = Cell(9, 6)
        score = 0
        dead = false
    }
}

// MARK: - Flap

struct FlapGame: View {
    @Binding var score: Int
    let paused: Bool

    @State private var y: Double = 0.5
    @State private var velocity: Double = 0
    @State private var pipes: [Pipe] = []
    @State private var dead = false
    @State private var started = false
    private let tick = Timer.publish(every: 1.0 / 50.0, on: .main, in: .common).autoconnect()

    struct Pipe: Identifiable {
        let id = UUID()
        var x: Double
        let gapY: Double
        var scored = false
        static let gap = 0.30
        static let width = 0.16
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Theme.bg
                ForEach(pipes) { p in
                    Group {
                        RoundedRectangle(cornerRadius: 5).fill(Theme.accentDim)
                            .frame(width: Pipe.width * geo.size.width,
                                   height: max(0, (p.gapY - Pipe.gap / 2) * geo.size.height))
                            .position(x: p.x * geo.size.width,
                                      y: (p.gapY - Pipe.gap / 2) * geo.size.height / 2)
                        RoundedRectangle(cornerRadius: 5).fill(Theme.accentDim)
                            .frame(width: Pipe.width * geo.size.width,
                                   height: max(0, (1 - p.gapY - Pipe.gap / 2) * geo.size.height))
                            .position(x: p.x * geo.size.width,
                                      y: geo.size.height - (1 - p.gapY - Pipe.gap / 2) * geo.size.height / 2)
                    }
                }
                Circle()
                    .fill(Theme.gold)
                    .frame(width: 20, height: 20)
                    .position(x: geo.size.width * 0.26, y: y * geo.size.height)
                    .rotationEffect(.degrees(min(50, max(-30, velocity * 900))))

                if !started || dead {
                    VStack(spacing: 6) {
                        Text(dead ? "Down you go." : "Tap to flap")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.text)
                        if dead {
                            Text("Tap to try again")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface.opacity(0.9)))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !paused else { return }
                if dead || !started { restart(); return }
                velocity = -0.0135
                Feedback.shared.tap()
            }
        }
        .onReceive(tick) { _ in step() }
    }

    private func step() {
        guard !paused, started, !dead else { return }
        velocity += 0.00072
        y += velocity
        if y < 0.02 || y > 0.98 { die(); return }

        for i in pipes.indices { pipes[i].x -= 0.0062 }
        pipes.removeAll { $0.x < -Pipe.width }
        if let last = pipes.last, last.x < 0.62 {
            pipes.append(Pipe(x: 1.15, gapY: .random(in: 0.28...0.72)))
        }

        for i in pipes.indices {
            let p = pipes[i]
            let inX = abs(p.x - 0.26) < (Pipe.width / 2 + 0.04)
            if inX && abs(y - p.gapY) > Pipe.gap / 2 { die(); return }
            if !p.scored && p.x < 0.26 {
                pipes[i].scored = true
                score += 1
                Feedback.shared.setChecked()
            }
        }
    }

    private func die() {
        dead = true
        started = false
        Feedback.shared.denied()
    }

    private func restart() {
        y = 0.5; velocity = -0.012
        pipes = [Pipe(x: 1.05, gapY: 0.5)]
        score = 0
        dead = false
        started = true
    }
}

import SwiftUI

/// Rest is part of the set, not a side button. It counts down, alarms at zero,
/// then keeps counting the overtime so the coach knows how long you actually needed.
struct RestPhaseView: View {
    let target: Int
    let nextLabel: String
    let store: Store
    let onDone: (Int) -> Void        // seconds actually rested

    @State private var elapsed = 0
    @State private var alarmed = false
    @State private var game: MiniGame?
    @State private var showShop = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var remaining: Int { max(0, target - elapsed) }
    private var overtime: Int { max(0, elapsed - target) }
    private var overdue: Bool { elapsed >= target }

    private var color: Color {
        if overdue { return Theme.flame }
        if remaining <= 10 { return Theme.danger }
        if remaining <= 25 { return Theme.gold }
        return Theme.accent
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                dial

                Text(statusLine)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(overdue ? Theme.flame : Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if let game {
                    MiniGameHost(game: game, locked: overdue) { self.game = nil }
                        .padding(.horizontal, 20)
                } else {
                    gamePicker
                }

                Button(nextLabel) { Feedback.shared.tap(); onDone(elapsed) }
                    .buttonStyle(ChunkyButtonStyle(color: overdue ? Theme.flame : Theme.accent,
                                                   textColor: Color(hex: 0x10221A)))
                    .padding(.horizontal, 20)

                Color.clear.frame(height: 20)
            }
            .padding(.top, 6)
        }
        .sheet(isPresented: $showShop) { GameShopView() }
        .onReceive(tick) { _ in
            elapsed += 1
            if elapsed >= target && !alarmed {
                alarmed = true
                Feedback.shared.timerDone()
            }
        }
    }

    private var dial: some View {
        ZStack {
            Circle().stroke(Theme.locked, lineWidth: 13).frame(width: 190, height: 190)
            Circle()
                .trim(from: 0, to: overdue ? 1 : Double(remaining) / Double(target))
                .stroke(color, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 190, height: 190)
                .shadow(color: color.opacity(0.45), radius: 12)
                .animation(.linear(duration: 0.9), value: elapsed)

            VStack(spacing: 0) {
                Text(overdue ? "+\(clock(overtime))" : clock(remaining))
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText(countsDown: !overdue))
                Text(overdue ? "extra rest" : "rest")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }
        }
        .frame(width: 210, height: 210)
    }

    private var gamePicker: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PASS THE TIME")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Button {
                    Feedback.shared.tap(); showShop = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "circlebadge.2.fill").font(.system(size: 11))
                        Text("\(store.profile.coins)")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(Theme.gold)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                ForEach(GameCatalog.all) { g in
                    let unlocked = store.isUnlocked(game: g.id)
                    Button {
                        Feedback.shared.tap()
                        if unlocked && !overdue { game = g } else { showShop = true }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: unlocked ? g.icon : "lock.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(unlocked ? g.tint : Theme.textDim)
                            Text(g.name)
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(unlocked ? Theme.text : Theme.textDim)
                            if !unlocked {
                                Text("\(g.cost)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(Theme.gold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .card(Theme.surface)
                        .opacity(overdue ? 0.4 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(overdue)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var statusLine: String {
        if overdue {
            if overtime > 90 { return "Long breather — the coach will lighten the load next session." }
            return "Rest's up. Take the extra time if you need it, it's all logged."
        }
        if remaining <= 10 { return "Get set — next one's coming." }
        return "Breathe. \(nextLabel.lowercased()) when the ring empties."
    }

    private func clock(_ s: Int) -> String { "\(s / 60):\(String(format: "%02d", s % 60))" }
}

struct GameShopView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Rest arcade")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "circlebadge.2.fill").foregroundStyle(Theme.gold)
                        Text("\(store.profile.coins)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.gold)
                            .contentTransition(.numericText())
                    }
                }
                Text("Coins come from the sets you actually finish — harder sets and honest rest pay more.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)

                ForEach(GameCatalog.all) { g in
                    let unlocked = store.isUnlocked(game: g.id)
                    HStack(spacing: 14) {
                        Image(systemName: g.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(g.tint)
                            .frame(width: 42, height: 42)
                            .background(RoundedRectangle(cornerRadius: 13).fill(g.tint.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name)
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text(g.blurb)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        if unlocked {
                            Text("Owned")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        } else {
                            Button {
                                if store.unlock(game: g.id, cost: g.cost) { Feedback.shared.celebrate() }
                                else { Feedback.shared.denied() }
                            } label: {
                                Text("\(g.cost)")
                                    .font(.system(size: 13, weight: .black, design: .rounded))
                                    .foregroundStyle(store.profile.coins >= g.cost ? Color(hex: 0x10221A) : Theme.textDim)
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Capsule().fill(store.profile.coins >= g.cost ? Theme.gold : Theme.surfaceHigh))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .card(Theme.surface)
                }

                Button("Done") { Feedback.shared.tap(); dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 6)
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationBackground(Theme.bg)
    }
}

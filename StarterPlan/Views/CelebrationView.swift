import SwiftUI

struct CelebrationView: View {
    let payload: CelebrationPayload
    let onClose: () -> Void

    @Environment(Store.self) private var store
    @State private var appeared = false
    @State private var xpShown = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.accentDim.opacity(0.35), Theme.bg],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
                .background(Theme.bg.ignoresSafeArea())

            ConfettiView()
                .allowsHitTesting(false)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Image(systemName: "trophy.fill")
                    .font(.system(size: 78))
                    .foregroundStyle(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.5), radius: 24)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -25))

                VStack(spacing: 6) {
                    Text(headline)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(payload.dayTitle) complete")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
                .opacity(appeared ? 1 : 0)

                HStack(spacing: 12) {
                    statTile(icon: "bolt.fill", value: "+\(xpShown)", label: "XP", color: Theme.gold)
                    statTile(icon: "flame.fill", value: "\(payload.streak)", label: payload.streak == 1 ? "day" : "days", color: Theme.flame)
                    statTile(icon: "circlebadge.2.fill", value: "+\(payload.coins)", label: "coins", color: Theme.teal)
                }
                .padding(.horizontal, 20)

                if !payload.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("The coach adjusted your plan", systemImage: "brain.head.profile")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.gold)
                        ForEach(payload.notes, id: \.self) { n in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 11)).foregroundStyle(Theme.textDim)
                                Text(n)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.text)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(Theme.surface)
                    .padding(.horizontal, 20)
                }

                if payload.wasBonus {
                    VStack(spacing: 4) {
                        Label("Bonus session", systemImage: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.gold)
                        Text("Half credit, and this one is still on your plan for its own day.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.center)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .card(Theme.surface)
                    .padding(.horizontal, 20)
                }

                Text(Copy.streak(payload.streak))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)

                Spacer()

                Button("Continue") { Feedback.shared.tap(); onClose() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.5)) { appeared = true }
            animateXP()
            if payload.streak > 0 && payload.streak % 7 == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Feedback.shared.milestone() }
            }
        }
    }

    private var headline: String {
        if payload.wasBonus { return "Extra credit!" }
        if payload.streak >= 7 { return "Unstoppable!" }
        if payload.streak >= 3 { return "\(payload.streak) days in a row!" }
        return ["Lesson complete!", "Nice work!", "That's a win."][payload.setsDone % 3]
    }

    private func animateXP() {
        let steps = max(payload.xp / 5, 1)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 + Double(i) * 0.02) {
                withAnimation(.easeOut(duration: 0.1)) {
                    xpShown = min(payload.xp, i * 5)
                }
            }
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText())
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .card(Theme.surface)
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    private let pieces: [ConfettiPiece] = (0..<70).map { _ in ConfettiPiece() }
    @State private var go = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { p in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(p.color)
                        .frame(width: p.size, height: p.size * 1.7)
                        .rotationEffect(.degrees(go ? p.spin : 0))
                        .position(x: p.x * geo.size.width,
                                  y: go ? geo.size.height + 60 : -60)
                        .animation(.easeIn(duration: p.duration).delay(p.delay), value: go)
                        .opacity(go ? 0.9 : 0)
                }
            }
        }
        .onAppear { go = true }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x = Double.random(in: 0.02...0.98)
    let size = Double.random(in: 6...11)
    let spin = Double.random(in: 180...900)
    let duration = Double.random(in: 1.8...3.4)
    let delay = Double.random(in: 0...0.9)
    let color = [Theme.accent, Theme.gold, Theme.teal, Theme.flame, Color(hex: 0xB388FF)].randomElement()!
}

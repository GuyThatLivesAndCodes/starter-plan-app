import SwiftUI

struct RestTimerOverlay: View {
    @State var remaining: Int
    let total: Int
    let onDone: () -> Void

    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var finished = false

    private var fraction: Double { Double(remaining) / Double(total) }

    private var color: Color {
        if remaining <= 5 { return Theme.danger }
        if remaining <= 20 { return Theme.gold }
        return Theme.accent
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
                .onTapGesture { close() }

            VStack(spacing: 26) {
                Text(finished ? "Time's up — back to it 💪" : "Catch your breath")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)

                ZStack {
                    Circle().stroke(Theme.locked, lineWidth: 14).frame(width: 210, height: 210)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 210, height: 210)
                        .shadow(color: color.opacity(0.5), radius: 14)
                        .animation(.linear(duration: 0.95), value: remaining)

                    VStack(spacing: 2) {
                        Text("\(remaining / 60):\(String(format: "%02d", remaining % 60))")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(color)
                            .contentTransition(.numericText(countsDown: true))
                        Text("rest").font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    }
                }
                .scaleEffect(remaining <= 5 && !finished ? 1.04 : 1)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: remaining)

                HStack(spacing: 12) {
                    Button("+30s") {
                        Feedback.shared.tap()
                        withAnimation { remaining += 30; finished = false }
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, 22).padding(.vertical, 12)
                    .background(Capsule().fill(Theme.surfaceHigh))

                    Button(finished ? "Done" : "Skip") { close() }
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x10221A))
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Capsule().fill(Theme.accent))
                }
                .buttonStyle(.plain)
            }
            .padding(34)
            .card(Theme.surface)
            .padding(.horizontal, 30)
        }
        .onReceive(timer) { _ in
            guard remaining > 0 else { return }
            withAnimation { remaining -= 1 }
            if remaining == 0 {
                finished = true
                Feedback.shared.timerDone()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { close() }
            }
        }
    }

    private func close() {
        timer.upstream.connect().cancel()
        withAnimation(.easeOut(duration: 0.2)) { onDone() }
    }
}

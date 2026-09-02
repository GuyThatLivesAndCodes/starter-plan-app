import SwiftUI

// MARK: - Hold timer (plank, hollow hold)

/// A stopwatch for the user to watch, nothing more. It doesn't grade anything —
/// the effort rating after the set is what the coach reads.
struct HoldTimerView: View {
    let exercise: Exercise
    let target: Int
    let setNumber: Int
    let onDone: (Int) -> Void        // seconds actually held

    @State private var elapsed = 0
    @State private var running = false
    @State private var passedTarget = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var fraction: Double { min(1, Double(elapsed) / Double(max(target, 1))) }
    private var color: Color {
        if elapsed >= target { return Theme.accent }
        if fraction > 0.6 { return Theme.gold }
        return Theme.teal
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Set \(setNumber) · hold for \(target)s")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                Text(exercise.name)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
            }

            ZStack {
                Circle().stroke(Theme.locked, lineWidth: 13).frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(color, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .shadow(color: color.opacity(0.45), radius: 12)
                    .animation(.linear(duration: 0.9), value: elapsed)
                VStack(spacing: 0) {
                    Text("\(elapsed)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                    Text(elapsed >= target ? "past target" : "seconds")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
            }
            .onTapGesture { toggle() }

            Text(running ? "Tap the ring to pause — hold as long as your form holds."
                         : (elapsed == 0 ? "Get into position, then start." : "Paused. Resume or log it."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button(running ? "Pause" : (elapsed == 0 ? "Start hold" : "Resume")) { toggle() }
                    .buttonStyle(ChunkyButtonStyle(color: running ? Theme.surfaceHigh : Theme.accent,
                                                   textColor: running ? Theme.text : Color(hex: 0x10221A)))
                Button("Log \(elapsed)s and continue") {
                    Feedback.shared.tap()
                    onDone(elapsed)
                }
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(elapsed > 0 ? Theme.accent : Theme.textDim)
                .buttonStyle(.plain)
                .disabled(elapsed == 0)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 10)
        .onReceive(tick) { _ in
            guard running else { return }
            elapsed += 1
            if elapsed == target && !passedTarget {
                passedTarget = true
                Feedback.shared.timerDone()      // a marker, not a stop sign
            }
        }
    }

    private func toggle() {
        Feedback.shared.tap()
        withAnimation { running.toggle() }
    }
}

// MARK: - Rep tally (ring rows, pull-ups, lunges)

struct RepTallyView: View {
    let exercise: Exercise
    let target: Int
    @Binding var reps: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Reps this set")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text("target \(target)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textDim.opacity(0.8))
            }

            HStack(spacing: 16) {
                pill("minus") { reps = max(0, reps - 1) }
                Text("\(reps)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(reps >= target ? Theme.accent : Theme.text)
                    .frame(minWidth: 80)
                    .contentTransition(.numericText())
                pill("plus") { reps += 1 }
            }

            Text(reps == 0 ? "Tap + as you go, or just log the target."
                           : (reps >= target ? "Target hit." : "\(target - reps) to go"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(reps >= target ? Theme.accent : Theme.textDim)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceHigh))
    }

    private func pill(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.shared.setChecked()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.bg))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AMRAP

struct AmrapView: View {
    let exercise: Exercise
    let minutes: Int
    let movements: [String]
    let bestRounds: Int
    let brief: String
    let onFinish: (_ rounds: Int, _ partial: Int, _ seconds: Int, _ splits: [Int]) -> Void

    @State private var elapsed = 0
    @State private var running = false
    @State private var rounds = 0
    @State private var partial = 0
    @State private var splits: [Int] = []
    @State private var lastRoundAt = 0
    @State private var finished = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var total: Int { minutes * 60 }
    private var remaining: Int { max(0, total - elapsed) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("\(minutes) MINUTE AMRAP")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.flame)
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                }

                Text(RunTracker.clock(remaining))
                    .font(.system(size: 62, weight: .black, design: .rounded))
                    .foregroundStyle(remaining <= 60 ? Theme.danger : Theme.accent)
                    .contentTransition(.numericText(countsDown: true))

                VStack(spacing: 8) {
                    ForEach(movements, id: \.self) { m in
                        HStack(spacing: 10) {
                            Circle().fill(Theme.accent).frame(width: 6, height: 6)
                            Text(m)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .card(Theme.surface)

                if !brief.isEmpty { CoachNote(text: brief) }

                if !running && !finished {
                    Button("Start the clock") { Feedback.shared.celebrate(); running = true }
                        .buttonStyle(ChunkyButtonStyle())
                } else if !finished {
                    Button {
                        Feedback.shared.exerciseDone()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            rounds += 1
                            splits.append(elapsed - lastRoundAt)
                            lastRoundAt = elapsed
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("ROUND \(rounds + 1) DONE")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                            if let last = splits.last {
                                Text("last round \(RunTracker.clock(last))")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .opacity(0.7)
                            }
                        }
                        .foregroundStyle(Color(hex: 0x10221A))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    counter("\(rounds)", "ROUNDS", Theme.accent)
                    counter(splits.isEmpty ? "—" : RunTracker.clock(splits.reduce(0, +) / splits.count), "AVG ROUND", Theme.teal)
                    counter(bestRounds > 0 ? "\(bestRounds)" : "—", "YOUR PB", Theme.gold)
                }

                if running || finished {
                    HStack {
                        Text("Partial reps into the next round")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                        Spacer()
                        Stepper("", value: $partial, in: 0...60).labelsHidden().tint(Theme.accent)
                        Text("\(partial)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.text)
                            .frame(minWidth: 26)
                    }
                    .padding(14)
                    .card(Theme.surface)
                }

                if finished || running {
                    Button(finished ? "Log it" : "End early") {
                        Feedback.shared.celebrate()
                        onFinish(rounds, partial, elapsed, splits)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: finished ? Theme.accent : Theme.surfaceHigh,
                                                   textColor: finished ? Color(hex: 0x10221A) : Theme.text))
                }

                Color.clear.frame(height: 20)
            }
            .padding(20)
        }
        .onReceive(tick) { _ in
            guard running, !finished else { return }
            elapsed += 1
            if remaining == 60 { Feedback.shared.denied() }          // one minute warning
            if remaining == 0 {
                finished = true
                running = false
                Feedback.shared.celebrate()
            }
        }
    }

    private func counter(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).card(Theme.surface)
    }
}

// MARK: - Fixed rounds with enforced rest

struct RoundsRunnerView: View {
    let exercise: Exercise
    let roundCount: Int
    let movements: [String]
    let restSeconds: Int
    let brief: String
    let onFinish: (_ rounds: Int, _ seconds: Int, _ splits: [Int]) -> Void

    @State private var round = 1
    @State private var checked: Set<Int> = []
    @State private var resting = false
    @State private var restLeft = 0
    @State private var elapsed = 0
    @State private var roundStart = 0
    @State private var splits: [Int] = []
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("ROUND \(min(round, roundCount)) OF \(roundCount)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.flame)
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                }

                HStack(spacing: 6) {
                    ForEach(1...roundCount, id: \.self) { r in
                        Capsule()
                            .fill(r < round ? Theme.accent : (r == round ? Theme.accent.opacity(0.45) : Theme.locked))
                            .frame(height: 8)
                    }
                }

                if !brief.isEmpty && round == 1 && !resting { CoachNote(text: brief) }

                if resting {
                    VStack(spacing: 12) {
                        Text(RunTracker.clock(restLeft))
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(restLeft <= 10 ? Theme.danger : Theme.teal)
                            .contentTransition(.numericText(countsDown: true))
                        Text("Rest is part of the workout here. Next round starts when this hits zero.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.center)
                        Button("Skip the rest") { Feedback.shared.tap(); endRest() }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .buttonStyle(.plain)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .card(Theme.surface)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(movements.enumerated()), id: \.offset) { i, m in
                            Button {
                                Feedback.shared.setChecked()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                                    if checked.contains(i) { checked.remove(i) } else { checked.insert(i) }
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Text(m)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(checked.contains(i) ? Theme.accent : Theme.text)
                                    Spacer()
                                    Image(systemName: checked.contains(i) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 24))
                                        .foregroundStyle(checked.contains(i) ? Theme.accent : Theme.locked)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 16)
                                .background(RoundedRectangle(cornerRadius: 16)
                                    .fill(checked.contains(i) ? Theme.accent.opacity(0.12) : Theme.surfaceHigh))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(round >= roundCount ? "Finish workout" : "Round done") {
                        completeRound()
                    }
                    .buttonStyle(ChunkyButtonStyle(
                        color: checked.count == movements.count ? Theme.accent : Theme.surfaceHigh,
                        textColor: checked.count == movements.count ? Color(hex: 0x10221A) : Theme.textDim))
                }

                HStack(spacing: 10) {
                    stat(RunTracker.clock(elapsed), "TOTAL")
                    stat(splits.isEmpty ? "—" : RunTracker.clock(splits.last!), "LAST ROUND")
                }

                Color.clear.frame(height: 20)
            }
            .padding(20)
        }
        .onReceive(tick) { _ in
            elapsed += 1
            guard resting else { return }
            restLeft -= 1
            if restLeft <= 0 { endRest() }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(Theme.text)
            Text(l).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12).card(Theme.surface)
    }

    private func completeRound() {
        Feedback.shared.exerciseDone()
        splits.append(elapsed - roundStart)
        roundStart = elapsed
        checked = []
        if round >= roundCount {
            onFinish(round, elapsed, splits)
        } else {
            round += 1
            restLeft = restSeconds
            withAnimation { resting = true }
        }
    }

    private func endRest() {
        Feedback.shared.timerDone()
        withAnimation { resting = false }
        roundStart = elapsed
    }
}

// MARK: - For time

struct ForTimeView: View {
    let exercise: Exercise
    let roundCount: Int
    let movements: [String]
    let previousBest: Int
    let brief: String
    let onFinish: (_ rounds: Int, _ seconds: Int, _ splits: [Int]) -> Void

    @State private var elapsed = 0
    @State private var running = false
    @State private var round = 0
    @State private var splits: [Int] = []
    @State private var lastAt = 0
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                VStack(spacing: 3) {
                    Text("\(roundCount) ROUNDS · FOR TIME")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.flame)
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                }

                Text(RunTracker.clock(elapsed))
                    .font(.system(size: 62, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())

                if previousBest > 0 {
                    Text("Best so far: \(RunTracker.clock(previousBest))")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(elapsed < previousBest ? Theme.accent : Theme.gold)
                }

                VStack(spacing: 8) {
                    ForEach(movements, id: \.self) { m in
                        HStack(spacing: 10) {
                            Circle().fill(Theme.flame).frame(width: 6, height: 6)
                            Text(m).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Theme.text)
                            Spacer()
                        }
                    }
                }
                .padding(16).frame(maxWidth: .infinity).card(Theme.surface)

                if !brief.isEmpty { CoachNote(text: brief) }

                if !running {
                    Button("Go") { Feedback.shared.celebrate(); running = true }
                        .buttonStyle(ChunkyButtonStyle())
                } else {
                    Button {
                        Feedback.shared.exerciseDone()
                        round += 1
                        splits.append(elapsed - lastAt)
                        lastAt = elapsed
                        if round >= roundCount {
                            running = false
                            Feedback.shared.celebrate()
                            onFinish(round, elapsed, splits)
                        }
                    } label: {
                        Text("ROUND \(round + 1) DONE")
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundStyle(Color(hex: 0x10221A))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 26)
                            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.accent))
                    }
                    .buttonStyle(.plain)

                    Button("Stop here") {
                        Feedback.shared.tap()
                        running = false
                        onFinish(round, elapsed, splits)
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .buttonStyle(.plain)
                }

                if !splits.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROUND SPLITS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                        ForEach(Array(splits.enumerated()), id: \.offset) { i, s in
                            HStack {
                                Text("Round \(i + 1)")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                                Spacer()
                                Text(RunTracker.clock(s))
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundStyle(i > 0 && s > splits[i - 1] ? Theme.gold : Theme.accent)
                            }
                        }
                    }
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).card(Theme.surface)
                }

                Color.clear.frame(height: 20)
            }
            .padding(20)
        }
        .onReceive(tick) { _ in if running { elapsed += 1 } }
    }
}

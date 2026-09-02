import SwiftUI

/// What you see when you tap today. Never "do you want to work out" — always
/// "which of these three". Mood reshapes the options, and every one of them
/// completes the day.
struct SessionChoiceView: View {
    let day: WorkoutDay
    let onPick: (WorkoutDay) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var mood: Mood?
    @State private var previewing: SessionOption?

    private var options: [SessionOption] {
        SessionMenu.options(for: day, mood: mood ?? .normal,
                            prefs: store.profile.preferences,
                            experience: store.profile.experience)
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header

                    if mood == nil {
                        moodPicker
                    } else {
                        moodSummary
                        ForEach(options) { option in
                            OptionCard(option: option) {
                                Feedback.shared.tap()
                                onPick(option.session)
                            } onPreview: {
                                Feedback.shared.tap()
                                previewing = option
                            }
                        }
                        Text("Whichever you pick counts as today. There's no wrong answer here.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    Color.clear.frame(height: 30)
                }
                .padding(20)
            }
        }
        .sheet(item: $previewing) { option in
            SessionPreviewSheet(option: option) {
                previewing = nil
                onPick(option.session)
            }
        }
    }

    private var header: some View {
        HStack {
            Button { Feedback.shared.tap(); dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 1) {
                Text("TODAY")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text(day.kind.isRest ? "Rest day" : day.kind.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
    }

    private var moodPicker: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("How are you feeling?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Then pick from what fits. The plan bends around you, not the other way round.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 10)

            VStack(spacing: 10) {
                ForEach(Mood.allCases) { m in
                    Button {
                        Feedback.shared.tap()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { mood = m }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: m.icon)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(tint(m))
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(tint(m).opacity(0.15)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.label)
                                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Text(m.prompt)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Theme.textDim)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var moodSummary: some View {
        HStack(spacing: 10) {
            Image(systemName: (mood ?? .normal).icon).foregroundStyle(tint(mood ?? .normal))
            Text("Feeling \((mood ?? .normal).label.lowercased())")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
            Spacer()
            Button("Change") {
                Feedback.shared.tap()
                withAnimation { mood = nil }
            }
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(Theme.accent)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceHigh))
    }

    private func tint(_ m: Mood) -> Color {
        switch m {
        case .fresh: return Theme.accent
        case .normal: return Theme.teal
        case .low: return Theme.gold
        case .sore: return Theme.flame
        case .rushed: return Color(hex: 0xB388FF)
        }
    }
}

// MARK: - Option card

struct OptionCard: View {
    let option: SessionOption
    let onStart: () -> Void
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: option.icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(option.isRecommended ? Theme.accent : Theme.textDim)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill((option.isRecommended ? Theme.accent : Theme.textDim).opacity(0.14)))

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.badge)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(option.isRecommended ? Color(hex: 0x10221A) : Theme.textDim)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(option.isRecommended ? Theme.accent : Theme.surfaceHigh))
                        Text("~\(option.minutes) min")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    }
                    Text(option.title)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(option.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !option.session.exercises.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(option.session.exercises.prefix(4), id: \.id) { ex in
                            HStack(spacing: 6) {
                                Circle().fill(Theme.accent.opacity(0.6)).frame(width: 4, height: 4)
                                Text(ex.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                                    .lineLimit(1)
                            }
                        }
                        if option.session.exercises.count > 4 {
                            Text("+\(option.session.exercises.count - 4) more")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textDim.opacity(0.7))
                        }
                    }
                    Spacer(minLength: 0)
                    SessionBodyMap(day: option.session)
                        .frame(width: 82, height: 92)
                }
            }

            HStack(spacing: 10) {
                Button(action: onStart) {
                    Text("Start")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x10221A))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent))
                }
                .buttonStyle(.plain)

                Button(action: onPreview) {
                    Text("Details")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceHigh))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner)
                .stroke(option.isRecommended ? Theme.accent.opacity(0.45) : .clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Preview sheet

struct SessionPreviewSheet: View {
    let option: SessionOption
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("About \(option.minutes) minutes · \(option.session.exercises.count) movements")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }

                if let note = option.session.note {
                    Text(note)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !option.session.exercises.isEmpty {
                    VStack(spacing: 10) {
                        Text("WHAT THIS WORKS")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SessionBodyMap(day: option.session)
                            .frame(height: 200)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .card(Theme.surface)

                    ForEach(option.session.exercises, id: \.id) { ex in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.text)
                                Text(Array(Set(ex.primary.map(\.plainLabel))).sorted().joined(separator: " · "))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Theme.textDim)
                            }
                            Spacer()
                            Text(ex.scheme)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                }

                Button("Start this one") { Feedback.shared.tap(); onStart() }
                    .buttonStyle(ChunkyButtonStyle())

                Button("Back") { Feedback.shared.tap(); dismiss() }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.plain)
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
    }
}

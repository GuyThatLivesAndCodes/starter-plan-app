import SwiftUI

struct ExerciseCard: View {
    let exercise: Exercise
    let checked: Set<Int>
    @Binding var weight: Double
    let bumpSuggested: Bool
    let onToggle: (Int) -> Void
    let onInfo: () -> Void
    let onAcceptBump: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(exercise.scheme)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
                Button(action: onInfo) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.textDim)
                }
                .buttonStyle(.plain)
            }

            if bumpSuggested {
                Button(action: onAcceptBump) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill").foregroundStyle(Theme.gold)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Ready to level up")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Text("Two clean sessions — add 5 lb")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                        }
                        Spacer()
                        Text("+5")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.gold)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.gold.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            if exercise.tracksWeight { weightRow }

            VStack(spacing: 10) {
                ForEach(1...exercise.sets, id: \.self) { n in
                    SetRow(number: n, total: exercise.sets, isChecked: checked.contains(n)) { onToggle(n) }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
    }

    private var weightRow: some View {
        HStack(spacing: 14) {
            Text("Weight")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textDim)
            Spacer()
            stepper("minus") { weight = max(0, weight - 5) }
            Text(weight == 0 ? "—" : "\(Int(weight)) lb")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
                .frame(minWidth: 76)
                .contentTransition(.numericText())
            stepper("plus") { weight += 5 }
        }
        .padding(.vertical, 12).padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surfaceHigh))
    }

    private func stepper(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.shared.tap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.bg))
        }
        .buttonStyle(.plain)
    }
}

struct SetRow: View {
    let number: Int
    let total: Int
    let isChecked: Bool
    let action: () -> Void

    @State private var bounce = false

    var body: some View {
        Button {
            action()
            bounce = true
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { bounce = false }
        } label: {
            HStack(spacing: 14) {
                Text("Set \(number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isChecked ? Theme.accent : Theme.text)
                Spacer()
                Text("of \(total)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isChecked ? Theme.accent : Color.clear)
                        .frame(width: 32, height: 32)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isChecked ? Theme.accent : Theme.locked, lineWidth: 2.5)
                        .frame(width: 32, height: 32)
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Color(hex: 0x10221A))
                    }
                }
                .scaleEffect(bounce ? 1.28 : 1)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(isChecked ? Theme.accent.opacity(0.12) : Theme.surfaceHigh))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isChecked ? Theme.accent.opacity(0.4) : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}

struct ExerciseInfoSheet: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text(exercise.scheme)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }

                block(icon: "figure.strengthtraining.traditional", title: "How to do it", body: exercise.howTo, color: Theme.teal)
                block(icon: "lightbulb.fill", title: "Form cue", body: exercise.cue, color: Theme.gold)

                Button("Got it") { Feedback.shared.tap(); dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.bg)
    }

    private func block(icon: String, title: String, body: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(body)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
    }
}

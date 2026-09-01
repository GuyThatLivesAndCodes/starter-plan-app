import SwiftUI

/// Collected once on first launch, editable any time from Settings.
/// Everything the coach estimates starts here.
struct BodyProfileForm: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isOnboarding: Bool

    @State private var age = 25
    @State private var feet = 5
    @State private var inches = 9
    @State private var weight = 165.0
    @State private var sex: BodySex = .unspecified
    @State private var experience: Experience = .beginner

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isOnboarding ? "Let's size this to you" : "Your details")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("The app uses this to pick your starting weights and to tell whether a session went well. Nothing leaves your phone.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                field("Age") {
                    HStack {
                        Text("\(age)").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Theme.accent)
                        Text("years").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textDim)
                        Spacer()
                        Stepper("", value: $age, in: 13...90).labelsHidden().tint(Theme.accent)
                    }
                }

                field("Height") {
                    HStack(spacing: 16) {
                        picker(value: $feet, range: 4...7, unit: "ft")
                        picker(value: $inches, range: 0...11, unit: "in")
                        Spacer()
                    }
                }

                field("Body weight") {
                    HStack {
                        Text("\(Int(weight))").font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(Theme.accent)
                        Text("lb").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textDim)
                        Spacer()
                        HStack(spacing: 8) {
                            roundBtn("minus") { weight = max(70, weight - 5) }
                            roundBtn("plus") { weight = min(450, weight + 5) }
                        }
                    }
                }

                field("Used to scale starting weights") {
                    HStack(spacing: 8) {
                        ForEach(BodySex.allCases) { s in
                            chip(s.label, selected: sex == s) { sex = s }
                        }
                    }
                }

                field("Lifting experience") {
                    VStack(spacing: 8) {
                        ForEach(Experience.allCases) { e in
                            Button {
                                Feedback.shared.tap(); experience = e
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(e.label)
                                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                                            .foregroundStyle(Theme.text)
                                        Text(e.blurb)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(Theme.textDim)
                                    }
                                    Spacer()
                                    Image(systemName: experience == e ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(experience == e ? Theme.accent : Theme.locked)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity)
                                .background(RoundedRectangle(cornerRadius: 14)
                                    .fill(experience == e ? Theme.accent.opacity(0.10) : Theme.surfaceHigh))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if preview > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles").foregroundStyle(Theme.gold)
                        Text("Starting squat estimate: **\(Int(preview)) lb**. The app adjusts it from your first session onward.")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.gold.opacity(0.10)))
                }

                Text("Not medical advice. If something hurts in a sharp or joint-deep way, stop and get it looked at.")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim.opacity(0.75))

                Button(isOnboarding ? "Start training" : "Save") {
                    Feedback.shared.celebrate()
                    store.saveBody(age: age, heightIn: Double(feet * 12 + inches),
                                   weightLb: weight, sex: sex, experience: experience)
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle())

                Color.clear.frame(height: 10)
            }
            .padding(24)
        }
        .background(Theme.bg)
        .onAppear {
            let p = store.profile
            if p.hasBody {
                age = p.age
                feet = Int(p.heightIn) / 12
                inches = Int(p.heightIn) % 12
                weight = p.bodyWeightLb
                sex = p.sex
                experience = p.experience
            }
        }
    }

    private var preview: Double {
        let p = Profile()
        p.age = age
        p.heightIn = Double(feet * 12 + inches)
        p.bodyWeightLb = weight
        p.sex = sex
        p.experience = experience
        guard let squat = Plan.strengthA.first(where: { $0.id == "back_squat" }) else { return 0 }
        return Coach.baseline(for: squat, profile: p)
    }

    private func field<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textDim)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
    }

    private func picker(value: Binding<Int>, range: ClosedRange<Int>, unit: String) -> some View {
        HStack(spacing: 6) {
            Text("\(value.wrappedValue)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text(unit).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(Theme.textDim)
            Stepper("", value: value, in: range).labelsHidden().tint(Theme.accent)
        }
    }

    private func roundBtn(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button { Feedback.shared.tap(); action() } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Theme.surfaceHigh))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button { Feedback.shared.tap(); action() } label: {
            Text(label)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? Color(hex: 0x10221A) : Theme.textDim)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surfaceHigh))
        }
        .buttonStyle(.plain)
    }
}

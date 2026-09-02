import SwiftUI

/// "I want to do more." Builds a session outside the plan from whatever the user
/// feels like training — logged in full, and it never touches the schedule.
struct FreestyleView: View {
    let onStart: (WorkoutDay) -> Void

    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var focus: Set<Muscle> = []
    @State private var minutes = 25

    private var session: WorkoutDay {
        Freestyle.session(focus: focus, minutes: minutes,
                          prefs: store.profile.preferences,
                          experience: store.profile.experience)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Extra session")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("Tap what you feel like working. This is logged in full and doesn't move your plan — do it as often as you like.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 12) {
                    BodyMap(selectable: true, selected: focus) { m in
                        if focus.contains(m) { focus.remove(m) } else { focus.insert(m) }
                    }
                    .frame(height: 240)

                    if focus.isEmpty {
                        Text("Nothing selected — you'll get a balanced full-body session.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textDim)
                    } else {
                        FlowChips(items: Array(Set(focus.map(\.plainLabel))).sorted())
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .card(Theme.surface)

                VStack(alignment: .leading, spacing: 10) {
                    Text("HOW LONG")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                    HStack(spacing: 8) {
                        ForEach(Freestyle.durations, id: \.self) { m in
                            Button {
                                Feedback.shared.tap(); minutes = m
                            } label: {
                                Text("\(m) min")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(minutes == m ? Color(hex: 0x10221A) : Theme.textDim)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Capsule().fill(minutes == m ? Theme.accent : Theme.surfaceHigh))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("YOUR SESSION")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                    ForEach(session.exercises, id: \.id) { ex in
                        HStack {
                            Text(ex.name)
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text(ex.scheme)
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.accent)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .card(Theme.surface)
                    }
                }

                Button("Start extra session") {
                    Feedback.shared.celebrate()
                    onStart(session)
                }
                .buttonStyle(ChunkyButtonStyle())

                Button("Just some mobility instead") {
                    Feedback.shared.tap()
                    onStart(Freestyle.mobilitySession())
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)

                Color.clear.frame(height: 20)
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
    }
}

/// Weekly body heat map for the History tab.
struct WeeklyBodyReport: View {
    @Environment(Store.self) private var store

    private var volume: [Muscle: Double] {
        let raw = store.muscleVolume()
        guard let peak = raw.values.max(), peak > 0 else { return [:] }
        return raw.mapValues { min(1, $0 / peak) }
    }

    private var neglected: [Muscle] {
        let raw = store.muscleVolume()
        return Muscle.allCases
            .filter { (raw[$0] ?? 0) < 0.5 }
            .filter { $0 != .forearms && $0 != .calves }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THIS WEEK'S WORK")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textDim)

            BodyMap(intensity: volume)
                .frame(height: 210)

            if volume.isEmpty {
                Text("Nothing logged in the last seven days. Your map fills in as you train.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            } else if neglected.count > 4 {
                Text("Barely touched: \(Array(Set(neglected.prefix(6).map(\.plainLabel))).sorted().joined(separator: ", ")).")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.gold)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Good spread this week — most of you got worked.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
    }
}
